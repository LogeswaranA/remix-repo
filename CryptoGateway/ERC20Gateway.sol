// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "hardhat/console.sol";

contract ERC20Payment is ReentrancyGuard
{
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private _purchaseIds;

    address marketBeneficiary;

    enum TokenType {
        USDT,
        USDC,
        DAI,
        USDZ
    }
    struct Buyer{
        uint256 id;
        uint256 amount;
        uint256 depositedOn;
        address buyer;
        TokenType tokentype;
    }

    mapping(uint256 => Buyer) public idToBuyers;

    constructor()
    {
        marketBeneficiary = msg.sender;
        _purchaseIds.increment();
    }

    event ERC20Transferred(
        uint256 indexed purchaseid,
        address indexed sender,
        address indexed beneficiary,
        uint256  amount,
        TokenType _tokenType
    );

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function makePayment(
        uint256 _amount,
        address _tokenAddress,
        TokenType _token
    ) public nonReentrant returns(bool val) {
        require(_amount > 0, "Amount cannot be 0");
        bool flag = false;
        if ((TokenType.USDT == TokenType(_token)) || 
            (TokenType.USDC == TokenType(_token)) || 
            (TokenType.DAI == TokenType(_token))  ||
            (TokenType.USDZ == TokenType(_token))
            ) {
            flag =true;
            uint256 _purchaseid = _purchaseIds.current();
            ERC20Balance(msg.sender, _tokenAddress, _amount);
            ERC20Allowance(msg.sender, _tokenAddress, _amount);
            idToBuyers[_purchaseid] = Buyer(
                                            _purchaseid,
                                            _amount,
                                            block.timestamp,
                                            msg.sender,
                                            TokenType(_token)
                                        );
            transferPayment(_amount, _tokenAddress, _token);
            emit ERC20Transferred(_purchaseid,msg.sender, marketBeneficiary, _amount,TokenType(_token));
            return flag;
        }else{
            require(flag,"Token Type is not supported");
        }
    }

    function ERC20Balance(
        address _addrToCheck,
        address _currency,
        uint256 _AmountToCheckAgainst
    ) internal view {
        require(
            IERC20(_currency).balanceOf(_addrToCheck) >=
                _AmountToCheckAgainst ,
            "ERC20Payment: insufficient currency balance"
        );
    }

    function ERC20Allowance(
        address _addrToCheck,
        address _currency,
        uint256 _AmountToCheckAgainst
    ) internal view {
        require(IERC20(_currency).allowance(_addrToCheck, address(this)) >=
                _AmountToCheckAgainst,
            "ERC20Payment: insufficient allowance."
        );
    }

    function increaseAllowance(
        uint256 _amount,
        address _currency
        )public {
        ERC20Balance(msg.sender,_currency,_amount);
        IERC20(_currency).approve(address(this),_amount);
    }    

    //internal function for transferpayment
    function transferPayment(
        uint256 _amount,
        address _tokenaddress,
        TokenType _token
    ) internal {
        // payable(marketBeneficiary).transfer(marketCut);
        //Transfer Market cut
        IERC20(_tokenaddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
    }

    //Function to return total PLI balance available in the contract
    function getTokenBalance(address _tokenAddress) public view returns (uint256 _balance) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    //Function to return total PLI balance available in the contract
    function withdraw(address _tokenAddress) public returns (bool) {
        uint256 _balance = IERC20(_tokenAddress).balanceOf(address(this));
        require(_balance > 0, "Balance for this token is 0");
        IERC20(_tokenAddress).transfer(msg.sender,_balance);
        return true;
    }

}
