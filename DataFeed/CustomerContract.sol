pragma solidity ^0.4.24;

interface IInvokeOracle{
    function requestData(address _caller) external returns (bytes32 requestId);
    function showPrice() external view returns(uint256);
}

contract CustomerContract{
    address CONTRACTADDR = 0xb75E36480418f464F9E9b0D21F00BFe9d2ea3D37;
    bytes32 public requestId; 

    //Fund this contract with sufficient PLI, before you trigger below function. 
    //Note, below function will not trigger if you do not put PLI in above contract address
    function getPriceInfo() external returns(bytes32){
        (requestId) = IInvokeOracle(CONTRACTADDR).requestData({_caller:msg.sender}); 
        return requestId;
    }
    //TODO - you can customize below function as you want, but below function will give you the pricing value
    //This function will give you last stored value in the contract
    function show() external view returns(uint256){
        return IInvokeOracle(CONTRACTADDR).showPrice();
    }
}