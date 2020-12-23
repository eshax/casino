pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

contract games {
    
    struct Data {
        uint code;
        uint amount;
    }
    
    Data[] private listData;
    uint private random_number;
    
    uint[] private redlist = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
    uint[] private blacklist = [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];
    
    uint[] private line1 = [1,4,7,10,13,16,19,22,25,28,31,34];
    uint[] private line2 = [2,5,8,11,14,17,20,23,26,29,32,35];
    uint[] private line3 = [3,6,9,12,15,18,21,24,27,30,33,36];
    
    
    function bet(Data[] memory data) public returns(uint, uint) {
        
        // 保存下注信息
        for (uint i=0; i<data.length; i++ ) {
            listData.push(data[i]);
        }
        
        // 开奖
        uint bonus = open();
        
        // 派奖
        if (bonus > 0) payment(bonus);
        
        return (random_number, bonus);
    }
    
    function create_random_number() private returns (uint) {
        return uint(keccak256(block.difficulty, block.number, now, block.timestamp)) % 37;
    }
    
    // 执行开奖
    // params:
    //   null
    // returns:
    //   uint  -- 开奖号码
    //   uint  -- 奖金
    //   bool  -- 是否中奖
    function open() private returns (uint) {
        
        // 生成一个 0 - 36 的随机数
        random_number = create_random_number();
        
        uint amount = 0;
        
        for ( uint j = 0; j < listData.length; j++ ) {
            amount += check(listData[j]);
        }
        
        return amount;
    }
    
    // 派奖
    function payment(uint bonus) private {
        
    }
    
    // 中奖检测
    function check(Data d) private returns (uint) {
        
        uint i = 0;
        
        uint c = 0;
        
        uint amount = 0;
        
        uint x = random_number;
        
        // 单注净值 (扣除 1% 的手续费)
        uint bv = d.amount - (d.amount / 100);
        
        // 数字 * 35
        if (d.code == x) amount += bv + (d.amount * 35);
        
        // 奇 * 1
        if (d.code == 41 && x % 2 == 1) amount += bv + (d.amount * 1);

        // 偶 * 1
        if (d.code == 42 && x % 2 == 0) amount += bv + (d.amount * 1);
        
        // 红 [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36] * 1
        if (d.code == 51){
            for (i = 0; i < redlist.length; i++ ) {
                if (redlist[i] == x) {
                    amount += bv + (d.amount * 1);
                    break;
                }
            }
        } 

        // 黑 [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35] * 1
        if (d.code == 52) {
            for (i = 0; i < blacklist.length; i++ ) {
                if (redlist[i] == x) {
                    amount += bv + (d.amount * 1);
                    break;
                }
            }
        }
        
        //  小号 [1 - 18] * 1
        if (d.code == 61) {
            if (x > 0 && x < 19 ) amount += bv + (d.amount * 1);
        }
        
        // 大号 [19 - 36] * 1
        if (d.code == 62) {
            if (x > 18 && x < 37 ) amount += bv + (d.amount * 1);
        }
        
        // group-1 [1 - 12] * 2
        if (d.code == 71) {
            if (x > 0 && x < 13 ) amount += bv + (d.amount * 2);
        }
        
        // group-2 [13 - 24] * 2
        if (d.code == 72) {
            if (x > 13 && x < 25 ) amount += bv + (d.amount * 2);
        }
        
        // group-3 [25 - 36] * 2
        if (d.code == 73) {
            if (x > 24 && x < 37 ) amount += bv + (d.amount * 2);
        }

        // line-1 [1,4,7,10,13,16,19,22,25,28,31,34] * 2
        if (d.code == 81) {
            for (i = 0; i < line1.length; i++ ) {
                if (line1[i] == x) {
                    amount += bv + (d.amount * 1);
                    break;
                }
            }
        }        
        
        // line-2 [2,5,8,11,14,17,20,23,26,29,32,35] * 2
        if (d.code == 82) {
            for (i = 0; i < line2.length; i++ ) {
                if (line2[i] == x) {
                    amount += bv + (d.amount * 1);
                    break;
                }
            }
        }        
        
        // line-3 [3,6,9,12,15,18,21,24,27,30,33,36] * 2
        if (d.code == 83) {
            for (i = 0; i < line3.length; i++ ) {
                if (line3[i] == x) {
                    amount += bv + (d.amount * 1);
                    break;
                }
            }
        }
        
        // 1/2 * 17   [low number] 例如 用户选择 1和2 那么 code = 201
        if (d.code > 200 && d.code < 300) {
            c = d.code - 200;
            if (x == c || x == c + 1) amount += bv + (d.amount * 17);
        }
        
        // 1/4 * 8    [low number] 例如 选择了 1和2和4和5 那么 code = 401
        if (d.code > 400 && d.code < 500) {
            c = d.code - 400;
            if (x == c || x == (c + 1) || x == (c + 3) || x == (c + 4)) amount += bv + (d.amount * 8);
        }
        
        // 1/5 * 6    [low number] 例如 选择了 1和2和3和4和5 那么 code = 501
        if (d.code > 500 && d.code < 600) {
            c = d.code - 500;
            if (x == c || x == (c + 1) || x == (c + 2) || x == (c + 3) || x == (c + 4)) amount += bv + (d.amount * 6);
        }

        return (amount);
    }

}