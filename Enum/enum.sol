// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract enumsample {

    enum Direction{EAST,WEST,SOUTH,NORTH}

    Direction public dir = Direction.NORTH;

    function checkMyVal(Direction _dir) public returns(Direction d){
        require(uint(_dir)<=3,"Enum value exceeds");
        for(uint i=0;i<=3;i++){
            if(Direction(_dir) == Direction(i)){
                dir = Direction(i);
                return dir;
            }
        }
    }

}
