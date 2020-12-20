pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

contract games {
    
    struct Data {
        uint code;
        uint amount;
    }
    
    Data[] private listData;
    
    function bet(Data[] memory data) public returns(uint, bool) {
        for (uint i=0; i<data.length; i++ ){
            listData.push(data[i]);
        }
        uint o = uint(keccak256(block.difficulty, block.number, now, block.timestamp)) % 37;
        bool b = false;
        uint n = 0;
        for (uint j=0; j<listData.length; j++) {
            Data d = listData[j];
            (n, b) = calc(d.code, d.amount);
        }
        return (o, b);
    }
    
    function calc(uint code, uint amount) private returns (uint, bool) {
        return (0, false);
    }

}