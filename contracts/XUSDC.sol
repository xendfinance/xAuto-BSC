// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
// import "./libraries/Ownable.sol";
import './libraries/TokenStructs.sol';
import './interfaces/FortubeToken.sol';
import './interfaces/FortubeBank.sol';
import './interfaces/IIEarnManager.sol';
import './interfaces/ITreasury.sol';
import './interfaces/IVenus.sol';

contract xUSDC is Context, IERC20, ReentrancyGuard, TokenStructs, Initializable {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  address private _owner;
  address private _candidate;
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  uint256 public pool;
  address public token;
  address public apr;
  address public fortubeToken;
  address public fortubeBank;
  address public feeAddress;
  uint256 public feeAmount;
  address public venusToken;
  uint256 public feePrecision;
  uint256 private lastWithdrawFeeTime;
  uint256 public totalDepositedAmount;

  mapping (address => uint256) depositedAmount;

  enum Lender {
      NONE,
      FORTUBE,
      VENUS
  }
  mapping (Lender => bool) public lenderStatus;
  mapping (Lender => bool) public withdrawable;

  Lender public provider = Lender.NONE;

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;
  uint8 private _decimals;
  
  constructor () public {}

  function initialize(
    address _apr
  ) public initializer{
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
    apr = _apr;
    _name = "xend USDC";
    _symbol = "xUSDC";
    token = address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    fortubeToken = address(0xb2CB0Af60372E242710c42e1C34579178c3D2BED);
    fortubeBank = address(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    feeAddress = address(0x143afc138978Ad681f7C7571858FAAA9D426CecE);
    venusToken = address(0xecA88125a5ADbe82614ffC12D0DB554E2e2867C8);
    feeAmount = 0;
    feePrecision = 1000;
    lenderStatus[Lender.FORTUBE] = true;
    lenderStatus[Lender.VENUS] = true;
    withdrawable[Lender.FORTUBE] = true;
    withdrawable[Lender.VENUS] = true;
    approveToken();
  }

  // Ownable setters incase of support in future for these systems
  function set_new_APR(address _new_APR) public onlyOwner {
      apr = _new_APR;
  }
  function set_new_feeAmount(uint256 fee) public onlyOwner{
    require(fee < feePrecision, 'fee amount must be less than 100%');
    feeAmount = fee;
  }
  function set_new_fee_address(address _new_fee_address) public onlyOwner {
      feeAddress = _new_fee_address;
  }
  function set_new_feePrecision(uint256 _newFeePrecision) public onlyOwner{
    require(_newFeePrecision >= 100, "fee precision must be greater than 100 at least");
    set_new_feeAmount(feeAmount*_newFeePrecision/feePrecision);
    feePrecision = _newFeePrecision;
  }
  // Quick swap low gas method for pool swaps
  function deposit(uint256 _amount)
      external
      nonReentrant
  {
      require(_amount > 0, "deposit must be greater than 0");
      pool = _calcPoolValueInToken();
      IERC20(token).safeTransferFrom(msg.sender, address(this), _amount);
      rebalance();
      // Calculate pool shares
      uint256 shares = 0;
      if (pool == 0) {
        shares = _amount;
        pool = _amount;
      } else {
        if (totalSupply() == 0) {
          shares = _amount;
        } else {
          uint256 fee = pool > totalDepositedAmount? pool.sub(totalDepositedAmount).mul(feeAmount).div(feePrecision) : 0;
          shares = (_amount.mul(totalSupply())).div(pool.sub(fee));
        }
      }
      pool = _calcPoolValueInToken();
      _mint(msg.sender, shares);
      depositedAmount[msg.sender] = depositedAmount[msg.sender].add(_amount);
      totalDepositedAmount = totalDepositedAmount.add(_amount);
      emit Deposit(msg.sender, _amount);
  }

  
  function withdraw(uint256 _shares)
      external
      nonReentrant
  {
      require(_shares > 0, "withdraw must be greater than 0");

      uint256 ibalance = balanceOf(msg.sender);
      require(_shares <= ibalance, "insufficient balance");

      // Could have over value from xTokens
      pool = _calcPoolValueInToken();
      // Calc to redeem before updating balances
      uint256 fee = pool > totalDepositedAmount? pool.sub(totalDepositedAmount).mul(feeAmount).div(feePrecision) : 0;
      uint256 r = (pool.sub(fee).mul(_shares)).div(totalSupply());

      emit Transfer(msg.sender, address(0), _shares);

      // Check balance
      uint256 b = _balance();
      if (b < r) {
        _withdrawSome(r.sub(b));
      }
      
      IERC20(token).safeTransfer(msg.sender, r);
      totalDepositedAmount = totalDepositedAmount.sub(_shares.mul(depositedAmount[msg.sender]).div(ibalance));
      depositedAmount[msg.sender] = depositedAmount[msg.sender].sub(_shares.mul(depositedAmount[msg.sender]).div(ibalance));
      _burn(msg.sender, _shares);
      rebalance();
      pool = _calcPoolValueInToken();
      emit Withdraw(msg.sender, _shares);
  }

  receive() external payable {}

  function recommend() public view returns (Lender) {
    (, uint256 ftapr, uint256 vapr,) = IIEarnManager(apr).recommend(token);
    uint256 max = 0;
    if (ftapr > max && lenderStatus[Lender.FORTUBE]) {
      max = ftapr;
    }
    if (vapr > max && lenderStatus[Lender.VENUS]) {
      max = vapr;
    }
    Lender newProvider = Lender.NONE;
    if (max == ftapr) {
      newProvider = Lender.FORTUBE;
    } else if (max == vapr) {
      newProvider = Lender.VENUS;
    }
    return newProvider;
  }

  function balance() external view returns (uint256) {
    return _balance();
  }

  function getDepositedAmount(address investor) public view returns (uint256) {
    return depositedAmount[investor];
  }

  function approveToken() public {
      IERC20(token).approve(FortubeBank(fortubeBank).controller(),  uint(-1));
      IERC20(token).approve(venusToken, uint(-1));
  }
  function balanceFortubeInToken() external view returns (uint256) {
    return _balanceFortubeInToken();
  }

  function balanceVenusInToken() external view returns (uint256) {
    return _balanceVenusInToken();
  }

  function balanceFortube() external view returns (uint256) {
    return _balanceFortube();
  }
  function balanceVenus() external view returns (uint256) {
    return _balanceVenus();
  }

  function _balance() internal view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function _balanceFortubeInToken() internal view returns (uint256) {
    uint256 b = _balanceFortube();
    if (b > 0 && withdrawable[Lender.FORTUBE]) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount).add(1);
    }
    return b;
  }

  function _balanceVenusInToken() internal view returns (uint256) {
    uint256 b = _balanceVenus();
    if (b > 0 && withdrawable[Lender.VENUS]) {
      uint256 exchangeRate = IVenus(venusToken).exchangeRateStored();
      b = b.mul(exchangeRate).div(1e18);
    }
    return b;

  }
  function _balanceFortube() internal view returns (uint256) {
    if(withdrawable[Lender.FORTUBE])
      return FortubeToken(fortubeToken).balanceOf(address(this));
    else
      return 0;
  }
  function _balanceVenus() internal view returns (uint256) {
    if(withdrawable[Lender.VENUS])
      return IERC20(venusToken).balanceOf(address(this));
    else
      return 0;
  }

  function _withdrawAll() internal {
    uint256  amount = _balanceFortube();
    if (amount > 0) {
      _withdrawFortube(amount);
    }
    amount = _balanceVenus();
    if (amount > 0) {
      _withdrawVenus(amount);
    }
  }

  function _withdrawSomeFortube(uint256 _amount) internal {
    uint256 b = _balanceFortube();
    uint256 bT = _balanceFortubeInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFortube(amount);
  }

function _withdrawSomeVenus(uint256 _amount) internal {
    uint256 b = _balanceVenus();
    uint256 bT = _balanceVenusInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawVenus(amount);
  }

  function _withdrawSome(uint256 _amount) internal {
    
    if (provider == Lender.FORTUBE) {
      _withdrawSomeFortube(_amount);
    }
    if (provider == Lender.VENUS) {
      _withdrawSomeVenus(_amount);
    }
  }

  function rebalance() public {
    Lender newProvider = recommend();

    if (newProvider != provider) {
      _withdrawAll();
    }

    if (_balance() > 1) {
      if (newProvider == Lender.FORTUBE) {
        supplyFortube(_balance());
      } else if (newProvider == Lender.VENUS) {
        supplyVenus(_balance());
      }
    }

    provider = newProvider;
  }

  function supplyFortube(uint amount) public {
      require(amount > 0, "FORTUBE: supply failed");
      FortubeBank(fortubeBank).deposit(FortubeToken(fortubeToken).underlying(), amount);
  }
  function supplyVenus(uint amount) public {
      require(amount > 0, "VENUS: supply failed");
      IVenus(venusToken).mint(amount);
  }
  function _withdrawFortube(uint amount) internal {
      require(amount > 0, "FORTUBE: withdraw failed");
      FortubeBank(fortubeBank).withdraw(FortubeToken(fortubeToken).underlying(), amount);
  }
  function _withdrawVenus(uint amount) internal {
      require(amount > 0, "VENUS: withdraw failed");
      IVenus(venusToken).redeem(amount);
  }
  function _calcPoolValueInToken() internal view returns (uint) {
    return _balanceFortubeInToken()
      .add(_balanceVenusInToken())
      .add(_balance());
  }

  function calcPoolValueInToken() public view returns (uint) {

    return _calcPoolValueInToken();
  }

  function getPricePerFullShare() public view returns (uint) {
    uint _pool = _calcPoolValueInToken();
    return _pool.mul(1e18).div(totalSupply());
  }

  function activateLender(Lender lender) public onlyOwner {
    lenderStatus[lender] = true;
    withdrawable[lender] = true;
    rebalance();
  }

  function deactivateWithdrawableLender(Lender lender) public onlyOwner {
    lenderStatus[lender] = false;
    rebalance();
  }

  function deactivateNonWithdrawableLender(Lender lender) public onlyOwner {
    lenderStatus[lender] = false;
    withdrawable[lender] = false;
    rebalance();
  }
  
  function withdrawFee() public {
    pool = _calcPoolValueInToken();
    uint256 amount = pool > totalDepositedAmount? pool.sub(totalDepositedAmount).mul(feeAmount).div(feePrecision).mul(block.timestamp.sub(lastWithdrawFeeTime)).div(365 * 24 * 60 * 60): 0;
    if(amount > 0){
      _withdrawSome(amount);
      IERC20(token).approve(feeAddress, amount);
      ITreasury(feeAddress).depositToken(token);
      lastWithdrawFeeTime = block.timestamp;
    }    
  }
  
    function name() public view virtual returns (string memory) {
        return _name;
    }
    
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }
    
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
  
    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _candidate = newOwner;
    }

    function acceptOwnership() external {
        require(msg.sender == _candidate, "Ownable: not cadidate");
        emit OwnershipTransferred(_owner, _candidate);
        _owner = _candidate;
    }
}