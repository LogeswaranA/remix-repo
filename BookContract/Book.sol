// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

contract BookContract 
{
    using Counters for Counters.Counter;

    Counters.Counter private _bookIds;

    struct Books{
        uint256 id;
        bytes32 keyHash;
        address owner;
        string bookName;
    }

    mapping(uint256 => Books) public idToBooks;
    mapping(string=>mapping(string=>bytes32)) private bookCodeMapping;
    mapping(bytes32=>string) private bookCodeHash;

    constructor()
    {
        _bookIds.increment();
    }

    event BookRegistered(
        uint256 indexed bookid,
        address indexed storedBy,
        string bookName
    );

    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function registerBook(
        string memory _code,
        string memory _bookName,
        string memory _bookHash
    ) public returns(bool) {
        uint256 _bookid = _bookIds.current();
        _bookIds.increment();
        bytes32 _keyHash =  keccak256(abi.encode(_bookName, _code));
        bookCodeHash[_keyHash] = _bookHash;
        bookCodeMapping[_bookName][_code]=_keyHash;
        idToBooks[_bookid] = Books(
                            _bookid,
                            _keyHash,
                            msg.sender,
                            _bookName
                    );
        emit BookRegistered(
            _bookid,
            msg.sender,
            _bookName
        );
        return true;
    }

    function fetchBook(string memory _code, string memory _bookName) public view returns(string memory _bookHash){
            bytes32 _generatedKeyHash = keccak256(abi.encode(_bookName, _code));
            bytes32 _actualkeyHash = bookCodeMapping[_bookName][_code];
            if(bytes32Equal(_generatedKeyHash,_actualkeyHash)){
                return bookCodeHash[_actualkeyHash];
            }
    }

    function bytes32Equal(bytes32 s1, bytes32 s2) private pure returns (bool) {
        uint256 l1 = s1.length;
        if (l1 != s2.length) return false;
        for (uint256 i=0; i<l1; i++) {
            if (s1[i] != s2[i]) return false;
        }
        return true;
    }

}
