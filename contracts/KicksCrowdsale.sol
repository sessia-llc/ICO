pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/crowdsale/emission/AllowanceCrowdsale.sol";
import "openzeppelin-solidity/contracts/crowdsale/validation/TimedCrowdsale.sol";
import "openzeppelin-solidity/contracts/access/roles/WhitelistedRole.sol";
import "openzeppelin-solidity/contracts/crowdsale/Crowdsale.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract KicksCrowdsale is Crowdsale, TimedCrowdsale, AllowanceCrowdsale, WhitelistedRole {

    using SafeMath for uint256;

    uint256 private _rate;

    uint256 private _kickCap = 33333333333333333333333333; // $50M
    uint256 private _kickMinPay = 100 ether;
    uint256 private _kickPurchased = 0;

    uint256 private _bonus20capBoundary = 800000000000000000000000; // $1.2M
    uint256 private _bonus10capBoundary = 1533333333333333333333333; // $2.3M

    address private _manualSeller;
    address private _rateSetter;
    address private _whitelistAdmin;

    bool private _KYC = false;

    event Bonus(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event ChangeRate(uint256 rate);

    constructor(
        uint256 rate, // eth to kick rate
        ERC20 token, // the kick token address
        address payable wallet, // accumulation eth address
        address tokenWallet, // kick storage address
        address manualSeller, // can sell tokens
        address rateSetter, // can change eth rate
        uint256 openingTime,
        uint256 closingTime
    )
    Crowdsale(rate, wallet, token)
    AllowanceCrowdsale(tokenWallet)
    TimedCrowdsale(openingTime, closingTime)
    public
    {
        _rate = rate;
        _manualSeller = manualSeller;
        _rateSetter = rateSetter;
        _whitelistAdmin = msg.sender;
    }


    /**
     * Base crowdsale override
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        if (_KYC) {
            require(isWhitelisted(beneficiary), 'Only whitelisted');
        }
        uint256 kickAmount = weiAmount.mul(_rate);
        require(kickAmount >= _kickMinPay, 'Min purchase 100 kick');
        require(_kickPurchased.add(kickAmount) <= _kickCap, 'Cap has been reached');
        super._preValidatePurchase(beneficiary, weiAmount);
    }

    function calcBonus(uint256 tokenAmount) internal view returns (uint256) {
        uint256 bonus = 0;
        if (_kickPurchased.add(tokenAmount) <= _bonus20capBoundary) {
            bonus = tokenAmount.mul(20).div(100);
        } else if (_kickPurchased.add(tokenAmount) <= _bonus10capBoundary) {
            bonus = tokenAmount.mul(10).div(100);
        }
        return bonus;
    }

    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        uint256 tokenAmount = weiAmount.mul(_rate);
        return tokenAmount.add(calcBonus(tokenAmount));
    }

    function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal {
        uint256 tokenAmount = weiAmount.mul(_rate);
        uint256 bonus = calcBonus(tokenAmount);
        if (bonus != 0) {
            emit Bonus(msg.sender, beneficiary, weiAmount, bonus);
            tokenAmount = tokenAmount.add(bonus);
        }
        _kickPurchased = _kickPurchased.add(tokenAmount);
    }


    /**
     * Manual sell
     */
    function manualSell(address beneficiary, uint256 weiAmount) public onlyWhileOpen {
        require(msg.sender == _manualSeller);
        _preValidatePurchase(beneficiary, weiAmount);
        uint256 tokens = _getTokenAmount(weiAmount);
        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(msg.sender, beneficiary, weiAmount, tokens);
        _updatePurchasingState(beneficiary, weiAmount);
        _postValidatePurchase(beneficiary, weiAmount);
    }


    /**
     * Change eth rate
     */
    function setRate(uint256 rate) public {
        require(msg.sender == _rateSetter);
        _rate = rate;
        emit ChangeRate(rate);
    }

    /**
     * Change KYC status
     */
    function onKYC() public {
        require(msg.sender == _whitelistAdmin);
        require(!_KYC);
        _KYC = true;
    }

    function offKYC() public {
        require(msg.sender == _whitelistAdmin);
        require(_KYC);
        _KYC = false;
    }


    /**
     * Getters
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    function kickCap() public view returns (uint256) {
        return _kickCap;
    }

    function kickMinPay() public view returns (uint256) {
        return _kickMinPay;
    }

    function kickPurchased() public view returns (uint256) {
        return _kickPurchased;
    }

    function bonus20capBoundary() public view returns (uint256) {
        return _bonus20capBoundary;
    }

    function bonus10capBoundary() public view returns (uint256) {
        return _bonus10capBoundary;
    }

    function KYC() public view returns (bool) {
        return _KYC;
    }
}
