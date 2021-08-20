pragma solidity ^0.5.0;
pragma experimental ABIEncoderV2;

import './libraries/Context.sol';
import './libraries/Ownable.sol';
import './interfaces/IERC20.sol';
import './libraries/SafeMath.sol';
import './libraries/Decimal.sol';
import './libraries/Address.sol';
import './libraries/SafeERC20.sol';
import './libraries/ReentrancyGuard.sol';
import './libraries/ERC20.sol';
import './libraries/ERC20Detailed.sol';
import './libraries/TokenStructs.sol';
import './interfaces/FortubeToken.sol';
import './interfaces/FortubeBank.sol';
import './interfaces/IIEarnManager.sol';
import './interfaces/ITreasury.sol';

contract xUSDC is ERC20, ERC20Detailed, ReentrancyGuard, Ownable, TokenStructs {
  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  uint256 public pool;
  address public token;
  address public apr;
  address public fortubeToken;
  address public fortubeBank;
  address public nerveAdapter;
  address public FEE_ADDRESS;
  uint256 public feeAmount;

  mapping (address => uint256) depositedAmount;

  enum Lender {
      NONE,
      FORTUBE,
      NERVE,
      VENUS
  }

  Lender public provider = Lender.NONE;

  constructor () public ERC20Detailed("xend USDC", "xUSDC", 18) {

    token = address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
    apr = address(0xdD6d648C991f7d47454354f4Ef326b04025a48A8);
    fortubeToken = address(0xb2CB0Af60372E242710c42e1C34579178c3D2BED);
    fortubeBank = address(0xc78248D676DeBB4597e88071D3d889eCA70E5469);
    nerveAdapter = address(0);
    FEE_ADDRESS = address(0x143afc138978Ad681f7C7571858FAAA9D426CecE);
    feeAmount = 0;
    approveToken();
  }

  // Ownable setters incase of support in future for these systems
  function set_new_APR(address _new_APR) public onlyOwner {
      apr = _new_APR;
  }
  function set_new_nerveAdapter(address _new_nerveAdapter) public onlyOwner{
    nerveAdapter = _new_nerveAdapter;
  }
  function set_new_feeAmount(uint256 fee) public onlyOwner{
    feeAmount = fee;
  }
  function set_new_fee_address(address _new_fee_address) public onlyOwner {
      FEE_ADDRESS = _new_fee_address;
  }
  // Quick swap low gas method for pool swaps
  function deposit(uint256 _amount)
      external
      nonReentrant
  {
      require(_amount > 0, "deposit must be greater than 0");
      rebalance();
      pool = _calcPoolValueInToken();

      IERC20(token).transferFrom(msg.sender, address(this), _amount);

      // Calculate pool shares
      uint256 shares = 0;
      if (pool == 0) {
        shares = _amount;
        pool = _amount;
      } else {
        shares = (_amount.mul(_totalSupply)).div(pool);
      }
      pool = _calcPoolValueInToken();
      _mint(msg.sender, shares);
      depositedAmount[msg.sender] = depositedAmount[msg.sender].add(_amount);
      emit Deposit(msg.sender, _amount);
  }

  // No rebalance implementation for lower fees and faster swaps
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
      uint256 r = (pool.mul(_shares)).div(_totalSupply);


      _balances[msg.sender] = _balances[msg.sender].sub(_shares, "redeem amount exceeds balance");
      _totalSupply = _totalSupply.sub(_shares);

      emit Transfer(msg.sender, address(0), _shares);

      // Check balance
      uint256 b = IERC20(token).balanceOf(address(this));
      if (b < r) {
        _withdrawSome(r.sub(b));
      }

      uint256 fee = (r.sub(depositedAmount[msg.sender])).mul(feeAmount).div(1000);
      if(fee > 0){
        IERC20(token).approve(FEE_ADDRESS, fee);
        ITreasury(FEE_ADDRESS).depositToken(token);
      }
      IERC20(token).transfer(msg.sender, r.sub(fee));
      depositedAmount[msg.sender] = depositedAmount[msg.sender].sub(r);
      rebalance();
      pool = _calcPoolValueInToken();
      emit Withdraw(msg.sender, _shares);
  }

  function() external payable {

  }

  function recommend() public view returns (Lender) {
    (, uint256 fapr, uint256 ftapr, uint256 napr, uint256 vapr) = IIEarnManager(apr).recommend(token);
    uint256 max = 0;
    if (fapr > max) {
      max = fapr;
    }
    if (ftapr > max) {
      max = ftapr;
    }
    if (napr > max) {
      max = napr;
    }
    if (vapr > max) {
      max = vapr;
    }
    Lender newProvider = Lender.NONE;
    if (max == ftapr) {
      newProvider = Lender.FORTUBE;
    } else if (max == napr) {
      newProvider = Lender.NERVE;
    } else if (max == vapr) {
      newProvider = Lender.VENUS;
    }
    return newProvider;
  }

  function balance() public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function getDepositedAmount(address investor) public view returns (uint256) {
    return depositedAmount[investor];
  }

  function approveToken() public {
      IERC20(token).approve(FortubeBank(fortubeBank).controller(),  uint(-1));
  }
  function balanceFortubeInToken() public view returns (uint256) {
    uint256 b = balanceFortube();
    if (b > 0) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount);
    }
    return b;
  }

  function balanceFortube() public view returns (uint256) {
    return FortubeToken(fortubeToken).balanceOf(address(this));
  }
  function balanceNerve() public view returns (uint256) {
    return INerveAdapter(nerveAdapter).getSupportedTokenBalance(address(this), 0);
  }
  function balanceVenus() public view returns (uint256) {
    return IERC20(venus).balanceOf(address(this));
  }

  function _balance() internal view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function _balanceFortubeInToken() internal view returns (uint256) {
    uint256 b = balanceFortube();
    if (b > 0) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount);
    }
    return b;
  }

  function _balanceNerveInToken() internal view returns (uint256) {

  }

  function _balanceVenusInToken() internal view returns (uint256) {

  }
  function _balanceFortube() internal view returns (uint256) {
    return IERC20(fortubeToken).balanceOf(address(this));
  }
  function _balanceNerve() internal view returns (uint256) {
    // return IERC20(fortubeToken).balanceOf(address(this));
  }
  function _balanceVenus() internal view returns (uint256) {
    // return IERC20(fortubeToken).balanceOf(address(this));
  }

  function _withdrawAll() internal {
    uint256  amount = _balanceFortube();
    if (amount > 0) {
      _withdrawFortube(amount);
    }
    amount = _balanceNerve();
    if (amount > 0) {
      _withdrawNerve(amount);
    }
    amount = _balanceVenus();
    if (amount > 0) {
      _withdrawVenus(amount);
    }
  }

  function _withdrawSomeFortube(uint256 _amount) internal {
    uint256 b = balanceFortube();
    uint256 bT = balanceFortubeInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFortube(amount);
  }

  function _withdrawSome(uint256 _amount) internal {
    // if (provider == Lender.AAVE) {
    //   require(balanceAave() >= _amount, "insufficient funds");
    //   _withdrawAave(_amount);
    // }

    if (provider == Lender.FORTUBE) {
      _withdrawSomeFortube(_amount);
    }
    if (provider == Lender.NERVE) {
      _withdrawSomeNerve(_amount);
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

    if (balance() > 0) {
      if (newProvider == Lender.FORTUBE) {
        supplyFortube(balance());
      } else if (newProvider == Lender.NERVE) {
        supplyNerve(balance());
      } else if (newProvider == Lender.VENUS) {
        supplyVenus(balance());
      }
    }

    provider = newProvider;
  }

  // Internal only rebalance for better gas in redeem
  function _rebalance(Lender newProvider) internal {
    if (_balance() > 0) {
      if (newProvider == Lender.FORTUBE) {
        supplyFortube(_balance());
      } else if (newProvider == Lender.NERVE) {
        supplyNerve(_balance());
      } else if (newProvider == Lender.VENUS) {
        supplyVenus(_balance());
      }
    }
    provider = newProvider;
  }

  function supplyFortube(uint amount) public {
      require(amount > 0, "FORTUBE: supply failed");
      FortubeBank(fortubeBank).deposit(token, amount);
  }
  function supplyNerve(uint amount) public {
      require(amount > 0, "NERVE: supply failed");
      INerveAdapter(nerveAdapter).deposit(amount, 2);
  }
  function supplyVenus(uint amount) public {
      require(amount > 0, "VENUS: supply failed");
      IVenus(venus).deposit(token, amount);
  }
  function _withdrawFortube(uint amount) internal {
      require(amount > 0, "FORTUBE: withdraw failed");
      FortubeBank(fortubeBank).withdraw(token, amount);
  }
  function _withdrawNerve(uint amount) internal {
      require(amount > 0, "NERVE: withdraw failed");
      INerveAdapter(nerveAdapter).withdrawBySharesOnly(amount, 2);
  }
  function _withdrawVenus(uint amount) internal {
      require(amount > 0, "VENUS: withdraw failed");
      IVenus(venus).withdraw(token, amount);
  }
  function _calcPoolValueInToken() internal view returns (uint) {
    return _balanceFortubeInToken()
      .add(_balanceNerveInToken())
      .add(_balanceVenusInToken())
      .add(_balance());
  }

  function calcPoolValueInToken() public view returns (uint) {

    return balanceFortubeInToken()
      .add(balanceNerveInToken())
      .add(balanceVenusInToken())
      .add(balance());
  }

  function getPricePerFullShare() public view returns (uint) {
    uint _pool = calcPoolValueInToken();
    return _pool.mul(1e18).div(_totalSupply);
  }
}