pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

/*

1:1 比例 
1个游戏币 = 1ETH

*/

contract Ownable {

    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    // function transferOwnership(address newOwner) public onlyOwner {
    //     require(newOwner != address(0), "Ownable: new owner is the zero address");
    //     emit OwnershipTransferred(_owner, newOwner);
    //     _owner = newOwner;
    // }

}

contract roulette_royale is Ownable {
    
    struct Data {
        uint code;
        uint amount;
    }
    
    struct Bet {
        Data[] data;
        address player;
        uint random_number;
        uint bonus;
    }
    
    mapping(uint => Bet) private Bets;
    
    uint[] private redlist      = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
    uint[] private blacklist    = [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];
    
    uint[] private line1        = [1,4,7,10,13,16,19,22,25,28,31,34];
    uint[] private line2        = [2,5,8,11,14,17,20,23,26,29,32,35];
    uint[] private line3        = [3,6,9,12,15,18,21,24,27,30,33,36];
    
    function() external payable {
        
    }
    
    /*
        合约销毁, 仅支持 owner 操作
    */
    function kill() external onlyOwner {
        selfdestruct(msg.sender);
    }

    /*
        合约提现, 仅支持 owner 操作
    */
    function withdraw(uint amount) external onlyOwner {
        msg.sender.transfer(amount);
    }


    /*
        下注接口
        
            params：
                data  -- 下注数据
            returns:
                uint  -- 
    */
    function bet(Data[] memory data) public payable returns (uint) {

        uint token = uint(keccak256(msg.sender, now));

        Bet storage bet = Bets[token];
        require (bet.player == address(0), "Bet should be in a 'clean' state.");

        uint total = 0;
        // 保存下注信息
        for (uint i = 0; i < data.length; i ++) {
            Data memory o = data[i];
            total += o.amount;
            bet.data.push(o);
        }
        
        // 实际 transfer 金额
        uint amount = msg.value;

        // 判断下注金额是否为0
        require(amount != 0, "msg.value is zero!");
        
        // 判断 msg value 是否与 下注累计金额相等
        require(amount == total, "msg.value is not equal bet amount!");
        
        bet.random_number = create_random();
        
        uint bonus = check(bet);
        
        require (bonus <= address(this).balance, "Cannot afford to lose this bet.");
        
        return (token);
    }
    
    function create_random() private returns (uint) {
        return uint(keccak256(block.difficulty, block.number, now, block.timestamp)) % 37;
    }
    
    /*
        执行开奖
        
            params:
                data  -- 下注数据
            returns:
                uint  -- 随机数
                uint  -- 奖金
    */
    function open(uint token) public returns (uint) {
        
        Bet storage bet = Bets[token];
        require (bet.data.length > 0, "no bet data.");
        
        uint bonus = check(bet);
        
        require (bonus <= address(this).balance, "Cannot afford to lose this bet.");
        
        // 派奖
        if (bonus > 0) msg.sender.transfer(bonus);
        
        delete Bets[token];
        
        return bonus;
    }
    
    
    function check(Bet bet) private returns (uint) {
        uint amount = 0;
        
        for ( uint i = 0; i < bet.data.length; i++ ) {
            Data memory d = bet.data[i];
            amount += check(bet.random_number, d);
        }
        
        return amount;
    }
    
    /*
        中奖检测
        
            params:
                uint  -- 随机数
                Data  -- 下注数据
                
            returns:
                uint  -- 奖金金额
            
    */
    function check(uint random_number, Data d) private returns (uint) {
        
        uint i = 0;
        
        uint c = 0;
        
        uint amount = 0;
        
        uint x = random_number;
        
        // 手续费
        uint fee = (d.amount / 100);
        
        // 最低手续费限制
        if (fee < 1e13) fee = 1e13;
        
        // 单注净值 (扣除 1% 的手续费)
        uint bv = d.amount - fee;
        
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
                    amount += bv + (d.amount * 2);
                    break;
                }
            }
        }
        
        // line-2 [2,5,8,11,14,17,20,23,26,29,32,35] * 2
        if (d.code == 82) {
            for (i = 0; i < line2.length; i++ ) {
                if (line2[i] == x) {
                    amount += bv + (d.amount * 2);
                    break;
                }
            }
        }
        
        // line-3 [3,6,9,12,15,18,21,24,27,30,33,36] * 2
        if (d.code == 83) {
            for (i = 0; i < line3.length; i++ ) {
                if (line3[i] == x) {
                    amount += bv + (d.amount * 2);
                    break;
                }
            }
        }
        
        // 1/2 * 17   [low number] 例如 用户选择 0和1 那么 code = 2001
        if (d.code == 2001 && (x == 0 || x == 1)) amount += bv + (d.amount * 17);
        if (d.code == 2002 && (x == 0 || x == 2)) amount += bv + (d.amount * 17);
        if (d.code == 2003 && (x == 0 || x == 3)) amount += bv + (d.amount * 17);

        // 1/2 * 17   [low number] 例如 用户选择 1和2 那么 code = 2101 横
        if (d.code > 2100 && d.code < 2200) {
            c = d.code - 2100;
            if (x == c || x == c + 1) amount += bv + (d.amount * 17);
        }

        // 1/2 * 17   [low number] 例如 用户选择 1和4 那么 code = 2201 竖
        if (d.code > 2200 && d.code < 2300) {
            c = d.code - 2200;
            if (x == c || x == c + 3) amount += bv + (d.amount * 17);
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
