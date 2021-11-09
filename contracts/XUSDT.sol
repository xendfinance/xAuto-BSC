// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Ownable.sol";
import './libraries/TokenStructs.sol';
import './interfaces/FortubeToken.sol';
import './interfaces/FortubeBank.sol';
import './interfaces/Fulcrum.sol';
import './interfaces/IIEarnManager.sol';
import './interfaces/ITreasury.sol';
import './interfaces/IVenus.sol';
import './interfaces/IAlpaca.sol';

contract xUSDT is ERC20, ReentrancyGuard, Ownable, TokenStructs {
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

  constructor () public ERC20("xend USDT", "xUSDT") {

    // bsc main network
    token = address(0x55d398326f99059fF775485246999027B3197955);
    apr = address(0x3a286653ae8EF3C35eE4849f57aF615eDA7d79ac);
    fulcrum = address(0xf326b42A237086F1De4E7D68F2d2456fC787bc01);
    fortubeToken = address(0xBf9213D046C2c1e6775dA2363fC47F10C4471255);
    fortubeBank = address(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    feeAddress = address(0x143afc138978Ad681f7C7571858FAAA9D426CecE);
    venusToken = address(0xfD5840Cd36d94D7229439859C0112a4185BC0255);
    alpacaToken = address(0x158Da805682BdC8ee32d52833aD41E74bb951E59);
    feeAmount = 0;
    feePrecision = 1000;
    approveToken();
    lenderStatus[Lender.FULCRUM] = true;
    lenderStatus[Lender.FORTUBE] = true;
    lenderStatus[Lender.VENUS] = true;
    lenderStatus[Lender.ALPACA] = true;
    withdrawable[Lender.FULCRUM] = true;
    withdrawable[Lender.FORTUBE] = true;
    withdrawable[Lender.VENUS] = true;
    withdrawable[Lender.ALPACA] = true;
  }

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
    assert(_newFeePrecision >= 100);
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
          shares = (_amount.mul(totalSupply())).div(pool);
        }
      }
      pool = _calcPoolValueInToken();
      _mint(msg.sender, shares);
      depositedAmount[msg.sender] = depositedAmount[msg.sender].add(_amount);
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
      uint256 i = (pool.mul(ibalance)).div(totalSupply());
      // Calc to redeem before updating balances
      uint256 r = (pool.mul(_shares)).div(totalSupply());
      if(i < depositedAmount[msg.sender]){
        i = i.add(1);
        r = r.add(1);
      }
      uint256 profit = (i.sub(depositedAmount[msg.sender])).mul(_shares.div(depositedAmount[msg.sender]));

      emit Transfer(msg.sender, address(0), _shares);

      // Check balance
      uint256 b = IERC20(token).balanceOf(address(this));
      if (b < r) {
        _withdrawSome(r.sub(b));
      }

      uint256 fee = profit.mul(feeAmount).div(feePrecision);
      if(fee > 0){
        IERC20(token).approve(feeAddress, fee);
        ITreasury(feeAddress).depositToken(token);
      }
      IERC20(token).safeTransfer(msg.sender, r.sub(fee));
      _burn(msg.sender, _shares);
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

  function balance() public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function getDepositedAmount(address investor) public view returns (uint256) {
    return depositedAmount[investor];
  }

  function approveToken() public {
      IERC20(token).approve(fulcrum, uint(-1));
      IERC20(token).approve(FortubeBank(fortubeBank).controller(),  uint(-1));
      IERC20(token).approve(venusToken, uint(-1));
      IERC20(token).approve(alpacaToken, uint(-1));
  }

  function balanceFortubeInToken() public view returns (uint256) {
    uint256 b = balanceFortube();
    if (b > 0 && withdrawable[Lender.FORTUBE]) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount).add(1);
    }
    return b;
  }

  function balanceFulcrumInToken() public view returns (uint256) {
    uint256 b = balanceFulcrum();
    if (b > 0 && withdrawable[Lender.FULCRUM]) {
      b = Fulcrum(fulcrum).assetBalanceOf(address(this)).add(1);
    }
    return b;
  }

  function balanceVenusInToken() public view returns (uint256) {
    uint256 b = balanceVenus();
    if (b > 0 && withdrawable[Lender.VENUS]) {
      uint256 exchangeRate = IVenus(venusToken).exchangeRateStored();
      b = b.mul(exchangeRate).div(1e28).add(1).mul(1e10);
    }
    return b;
  }

  function balanceAlpacaInToken() public view returns (uint256) {
    uint256 b = balanceAlpaca();
    if (b > 0 && withdrawable[Lender.ALPACA]) {
      b = b.mul(IAlpaca(alpacaToken).totalToken()).div(IAlpaca(alpacaToken).totalSupply()).add(1);
    }
    return b;
  }

  function balanceFulcrum() public view returns (uint256) {
    if(withdrawable[Lender.FULCRUM])
      return IERC20(fulcrum).balanceOf(address(this));
    else
      return 0;
  }

  function balanceFortube() public view returns (uint256) {
    if(withdrawable[Lender.FORTUBE])
      return FortubeToken(fortubeToken).balanceOf(address(this));
    else
      return 0;
  }
  function balanceVenus() public view returns (uint256) {
    if(withdrawable[Lender.VENUS])
      return IERC20(venusToken).balanceOf(address(this));
    else
      return 0;
  }

  function balanceAlpaca() public view returns (uint256) {
    if(withdrawable[Lender.VENUS])
      return IAlpaca(alpacaToken).balanceOf(address(this));
    else
      return 0;
  }

  function _balance() internal view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  function _balanceFulcrumInToken() internal view returns (uint256) {
    uint256 b = balanceFulcrum();
    if (b > 0 && withdrawable[Lender.FULCRUM]) {
      b = Fulcrum(fulcrum).assetBalanceOf(address(this)).add(1);
    }
    return b;
  }

  function _balanceFortubeInToken() internal view returns (uint256) {
    uint256 b = balanceFortube();
    if (b > 0 && withdrawable[Lender.FORTUBE]) {
      uint256 exchangeRate = FortubeToken(fortubeToken).exchangeRateStored();
      uint256 oneAmount = FortubeToken(fortubeToken).ONE();
      b = b.mul(exchangeRate).div(oneAmount).add(1);
    }
    return b;
  }

  function _balanceVenusInToken() internal view returns (uint256) {
    uint256 b = balanceVenus();
    if (b > 0 && withdrawable[Lender.VENUS]) {
      uint256 exchangeRate = IVenus(venusToken).exchangeRateStored();
      b = b.mul(exchangeRate).div(1e28).add(1).mul(1e10);
    }
    return b;
  }

  function _balanceAlpacaInToken() internal view returns (uint256) {
    uint256 b = balanceAlpaca();
    if (b > 0 && withdrawable[Lender.ALPACA]) {
      b = b.mul(IAlpaca(alpacaToken).totalToken()).div(IAlpaca(alpacaToken).totalSupply()).add(1);
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
    uint256 b = balanceFulcrum();
    // Balance of token in fulcrum
    uint256 bT = balanceFulcrumInToken();
    require(bT >= _amount, "insufficient funds");
    // can have unintentional rounding errors
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFulcrum(amount);
  }

  function _withdrawSomeFortube(uint256 _amount) internal {
    uint256 b = balanceFortube();
    uint256 bT = balanceFortubeInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT).add(1);
    _withdrawFortube(amount);
  }

  function _withdrawSomeVenus(uint256 _amount) internal {
    uint256 b = balanceVenus();
    uint256 bT = _balanceVenusInToken();
    require(bT >= _amount, "insufficient funds");
    uint256 amount = (b.mul(_amount)).div(bT);
    _withdrawVenus(amount);
  }

  function _withdrawSomeAlpaca(uint256 _amount) internal {
    uint256 b = balanceAlpaca();
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

    if (balance() > 0) {
      if (newProvider == Lender.FULCRUM) {
        supplyFulcrum(balance());
      } else if (newProvider == Lender.FORTUBE) {
        supplyFortube(balance());
      } else if (newProvider == Lender.VENUS) {
        supplyVenus(balance());
      } else if (newProvider == Lender.ALPACA) {
        supplyAlpaca(balance());
      }
    }

    provider = newProvider;
  }

  // Internal only rebalance for better gas in redeem
  function _rebalance(Lender newProvider) internal {
    if (_balance() > 0) {
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
      require(Fulcrum(fulcrum).mint(address(this), amount) > 0, "FULCRUM: supply failed");
  }
  function supplyFortube(uint amount) public {
      require(amount > 0, "FORTUBE: supply failed");
      FortubeBank(fortubeBank).deposit(FortubeToken(fortubeToken).underlying(), amount);
  }
  function supplyVenus(uint amount) public {
      require(amount > 0, "VENUS: supply failed");
      IVenus(venusToken).mint(amount);
  }
  function supplyAlpaca(uint amount) public {
      require(amount > 0, "ALPACA: supply failed");
      IAlpaca(alpacaToken).deposit(amount);
  }
  function _withdrawFulcrum(uint amount) internal {
      require(Fulcrum(fulcrum).burn(address(this), amount) > 0, "FULCRUM: withdraw failed");
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

    return balanceFulcrumInToken()
      .add(balanceFortubeInToken())
      .add(balanceVenusInToken())
      .add(balanceAlpacaInToken())
      .add(balance());
  }

  function getPricePerFullShare() public view returns (uint) {
    uint _pool = calcPoolValueInToken();
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
}