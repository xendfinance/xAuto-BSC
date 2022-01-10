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
import "./libraries/Ownable.sol";
import './libraries/TokenStructs.sol';
import './interfaces/FortubeToken.sol';
import './interfaces/FortubeBank.sol';
import './interfaces/Fulcrum.sol';
import './interfaces/IIEarnManager.sol';
import './interfaces/ITreasury.sol';
import './interfaces/IAlpaca.sol';

interface IVenus {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function mint() external payable;
    function redeem(uint redeemTokens) external returns(uint);
    function exchangeRateStored() external view returns (uint256);
}

contract xBNB is Context, IERC20, ReentrancyGuard, Ownable, TokenStructs, Initializable {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 public pool;
  address public token;
  address public fulcrum;
  address public apr;
  address public fortubeToken;
  address public fortubeBank;
  address public feeAddress;
  uint256 public feeAmount;
  address public venusToken;
  uint256 public feePrecision;
  address public alpacaToken;
  uint256 private lastWithdrawFeeTime;
  uint256 public totalDepositedAmount;

  mapping (address => uint256) depositedAmount;

  enum Lender {
      NONE,
      FULCRUM,
      FORTUBE,
      VENUS,
      ALPACA
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
    apr = _apr;
    _name = "xend BNB";
    _symbol = "xBNB";
    token = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    fulcrum = address(0xB8329B5458B1E493EFd8D9DA8C3B5E6D68e67C21);
    fortubeToken = address(0xf330b39f74e7f71ab9604A5307690872b8125aC8);
    fortubeBank = address(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    feeAddress = address(0x143afc138978Ad681f7C7571858FAAA9D426CecE);
    venusToken = address(0xA07c5b74C9B40447a954e1466938b865b6BBea36);
    alpacaToken = address(0xd7D069493685A581d27824Fc46EdA46B7EfC0063);
    feeAmount = 0;
    feePrecision = 1000;
    lenderStatus[Lender.FULCRUM] = true;
    lenderStatus[Lender.FORTUBE] = true;
    lenderStatus[Lender.VENUS] = true;
    lenderStatus[Lender.ALPACA] = true;
    withdrawable[Lender.FULCRUM] = true;
    withdrawable[Lender.FORTUBE] = true;
    withdrawable[Lender.VENUS] = true;
    withdrawable[Lender.ALPACA] = true;
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
  function deposit()
      external
      payable
      nonReentrant
  {
      uint256 _amount = msg.value;
      require(_amount > 0, "deposit must be greater than 0");      
      pool = _calcPoolValueInToken().sub(_amount);
      
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
      uint256 b = address(this).balance;
      if (b < r) {
        _withdrawSome(r.sub(b));
      }
      bool success;
      (success,) = payable(msg.sender).call{value: r}("");
      require(success, "Failed to send BNB");

      _burn(msg.sender, _shares);
      totalDepositedAmount = totalDepositedAmount.sub(_shares.mul(depositedAmount[msg.sender]).div(ibalance));
      depositedAmount[msg.sender] = depositedAmount[msg.sender].sub(_shares.mul(depositedAmount[msg.sender]).div(ibalance));
      rebalance();
      pool = _calcPoolValueInToken();
      emit Withdraw(msg.sender, _shares);
  }

  receive() external payable {}

  function recommend() public view returns (Lender) {
    (uint256 fapr, uint256 ftapr, uint256 vapr, uint256 aapr) = IIEarnManager(apr).recommend(token);
    uint256 max = 0;
    if (fapr > max && lenderStatus[Lender.FULCRUM]) {
      max = fapr;
    }
    if (ftapr > max && lenderStatus[Lender.FORTUBE]) {
      max = ftapr;
    }
    if (vapr > max && lenderStatus[Lender.VENUS]) {
      max = vapr;
    }
    if (aapr > max && lenderStatus[Lender.ALPACA]) {
      max = aapr;
    }
    Lender newProvider = Lender.NONE;
    if (max == fapr) {
      newProvider = Lender.FULCRUM;
    } else if (max == ftapr) {
      newProvider = Lender.FORTUBE;
    } else if (max == vapr) {
      newProvider = Lender.VENUS;
    } else if (max == aapr) {
      newProvider = Lender.ALPACA;
    }
    return newProvider;
  }

  function balance() external view returns (uint256) {
    return _balance();
  }

  function getDepositedAmount(address investor) public view returns (uint256) {
    return depositedAmount[investor];
  }

  function balanceFortubeInToken() external view returns (uint256) {
    return _balanceFortubeInToken();
  }

  function balanceFulcrumInToken() external view returns (uint256) {
    return _balanceFulcrumInToken();
  }

  function balanceVenusInToken() external view returns (uint256) {
    return _balanceVenusInToken();
  }

  function balanceAlpacaInToken() external view returns (uint256) {
    return _balanceAlpacaInToken();
  }

  function balanceFulcrum() external view returns (uint256) {
    return _balanceFulcrum();
  }
  function balanceFortube() external view returns (uint256) {
    return _balanceFortube();
  }
  function balanceVenus() external view returns (uint256) {
    return _balanceVenus();
  }

  function balanceAlpaca() external view returns (uint256) {
    return _balanceAlpaca();
  }

  function _balance() internal view returns (uint256) {
    return address(this).balance;
  }

  function _balanceFulcrumInToken() internal view returns (uint256) {
  
    uint256 b = _balanceFulcrum();
    if (b > 0 && withdrawable[Lender.FULCRUM]) {
      b = Fulcrum(fulcrum).assetBalanceOf(address(this));
    }
    return b;
  }

  function _balanceFortubeInToken() internal view returns (uint256) {
    uint256 b = _balanceFortube();
    if (b > 0 && withdrawable[Lender.FORTUBE]) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount);
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

  function _balanceAlpacaInToken() internal view returns (uint256) {
    uint256 b = _balanceAlpaca();
    if (b > 0 && withdrawable[Lender.ALPACA]) {
      b = b.mul(IAlpaca(alpacaToken).totalToken()).div(IAlpaca(alpacaToken).totalSupply());
    }
    return b;
  }

  function _balanceFulcrum() internal view returns (uint256) {
    if(withdrawable[Lender.FULCRUM])
      return IERC20(fulcrum).balanceOf(address(this));
    else
      return 0;
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

  function _balanceAlpaca() public view returns (uint256) {
    if(withdrawable[Lender.VENUS])
      return IAlpaca(alpacaToken).balanceOf(address(this));
    else
      return 0;
  }

  function _withdrawAll() internal {
    uint256  amount = _balanceFulcrum();
    if (amount > 0) {
      _withdrawFulcrum(amount);
    }
    amount = _balanceFortube();
    if (amount > 0) {
      _withdrawFortube(amount);
    }
    amount = _balanceVenus();
    if (amount > 0) {
      _withdrawVenus(amount);
    }
    amount = _balanceAlpaca();
    if (amount > 0) {
      _withdrawAlpaca(amount);
    }
  }

  function _withdrawSomeFulcrum(uint256 _amount) internal {
    uint256 b = _balanceFulcrum();
    // Balance of token in fulcrum
    uint256 bT = _balanceFulcrumInToken();
    require(bT >= _amount, "insufficient funds");
    // can have unintentional rounding errors
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFulcrum(amount);
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

  function _withdrawSomeAlpaca(uint256 _amount) internal {
    uint256 b = _balanceAlpaca();
    uint256 bT = _balanceAlpacaInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawAlpaca(amount);
  }

  function _withdrawSome(uint256 _amount) internal {
    if (provider == Lender.FULCRUM) {
      _withdrawSomeFulcrum(_amount);
    }
    if (provider == Lender.FORTUBE) {
      _withdrawSomeFortube(_amount);
    }
    if (provider == Lender.VENUS) {
      _withdrawSomeVenus(_amount);
    }
    if (provider == Lender.ALPACA) {
      _withdrawSomeAlpaca(_amount);
    }
  }

  function rebalance() public {
    Lender newProvider = recommend();

    if (newProvider != provider) {
      _withdrawAll();
    }

    if (_balance() > 1) {
      if (newProvider == Lender.FULCRUM) {
        supplyFulcrum(_balance());
      } else if (newProvider == Lender.FORTUBE) {
        supplyFortube(_balance());
      } else if (newProvider == Lender.VENUS) {
        supplyVenus(_balance());
      } else if (newProvider == Lender.ALPACA) {
        supplyAlpaca(_balance());
      }
    }

    provider = newProvider;
  }

  function supplyFulcrum(uint amount) public {
    require(Fulcrum(fulcrum).mintWithEther{value: amount}(address(this)) > 0, "FULCRUM: supply failed");
  }
  function supplyFortube(uint amount) public {
      require(amount > 0, "FORTUBE: supply failed");
      FortubeBank(fortubeBank).deposit{value: amount}(FortubeToken(fortubeToken).underlying(), amount);
  }
  function supplyVenus(uint amount) public {
      require(amount > 0, "VENUS: supply failed");
      IVenus(venusToken).mint{value: amount}();
  }
  function supplyAlpaca(uint amount) public {
      require(amount > 0, "ALPACA: supply failed");
      IAlpaca(alpacaToken).deposit{value: amount}(amount);
  }
  function _withdrawFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).burnToEther(address(this), amount) > 0, "FULCRUM: withdraw failed");
  }
  function _withdrawFortube(uint amount) internal {
      require(amount > 0, "FORTUBE: withdraw failed");
      FortubeBank(fortubeBank).withdraw(FortubeToken(fortubeToken).underlying(), amount);
  }
  function _withdrawVenus(uint amount) internal {
      require(amount > 0, "VENUS: withdraw failed");
      IVenus(venusToken).redeem(amount);
  }
  function _withdrawAlpaca(uint amount) internal {
      require(amount > 0, "ALPACA: withdraw failed");
      IAlpaca(alpacaToken).withdraw(amount);
  }

  function _calcPoolValueInToken() internal view returns (uint) {
    return _balanceFulcrumInToken()
      .add(_balanceFortubeInToken())
      .add(_balanceVenusInToken())
      .add(_balanceAlpacaInToken())
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
      (bool success,) = payable(feeAddress).call{value: amount}("");
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
}