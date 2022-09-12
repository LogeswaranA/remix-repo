// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@goplugin/contracts/src/v0.8/PluginClient.sol";

contract CryptoPay is PluginClient {
    
  //Initialize Oracle Payment     
  uint256 constant private ORACLE_PAYMENT =  0.1 * 10 ** 18;
  uint256 public currentPrice;

  //Initialize event RequestPriceFulfilled   
  event RequestPriceFulfilled(
    bytes32 indexed requestId,
    uint256 indexed price
  );

  //Initialize event requestCreated   
  event requestCreated(address indexed requester,bytes32 indexed jobId, bytes32 indexed requestId);

  //Constructor to pass Pli Token Address during deployment
  constructor(address _pli) public {
    setPluginToken(_pli);
  }
  
  //requestPrice function will initate the request to Oracle to get the price from Vinter API
  function requestPrice(address _oracle, string memory _jobId,string memory _endpoint,string memory _fsymbol,string memory _tsymbol)
    public
    returns (bytes32 requestId)
  {
    Plugin.Request memory req = buildPluginRequest(stringToBytes32(_jobId), address(this), this.fulfillPrice.selector);
    req.add("endpoint",_endpoint);
    req.add("fsymbol",_fsymbol);
    req.add("tsymbol",_tsymbol);
    req.addInt("times", 100);
    requestId = sendPluginRequestTo(_oracle, req, ORACLE_PAYMENT);
    emit requestCreated(msg.sender, stringToBytes32(_jobId), requestId);
  }

  //callBack function
  function fulfillPrice(bytes32 _requestId, uint256 _price)
    public
    recordPluginFulfillment(_requestId)
  {
    emit RequestPriceFulfilled(_requestId, _price);
    currentPrice = _price;
  }

  function getPluginToken() public view returns (address) {
    return pluginTokenAddress();
  }

  //With draw pli can be invoked only by owner
  function withdrawPli() public {
    PliTokenInterface pli = PliTokenInterface(pluginTokenAddress());
    require(pli.transfer(msg.sender, pli.balanceOf(address(this))), "Unable to transfer");
  }

  //Cancel the existing request
  function cancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  )
    public
  {
    cancelPluginRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }

  //String to bytes to convert jobid to bytest32
  function stringToBytes32(string memory source) private pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }
    assembly { 
      result := mload(add(source, 32))
    }
  }

}