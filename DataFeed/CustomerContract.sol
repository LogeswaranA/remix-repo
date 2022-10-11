pragma solidity ^0.4.24;

interface IInvokeOracle{
    function requestData(address _caller) external returns (bytes32 requestId);
    function showPrice() external view returns(uint256);
}

contract CustomerContract{
    address CONTRACTADDR = 0x1a8D6F587456b5b28e9f76D53fC38545E184D381;
    bytes32 public requestId; 
    function getPriceInfo() external returns(bytes32){
        (requestId) = IInvokeOracle(CONTRACTADDR).requestData({_caller:msg.sender}); 
        return requestId;
    }
    function show() external view returns(uint256){
        return IInvokeOracle(CONTRACTADDR).showPrice();
    }
}