pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

/*

1:1 比例 
1个游戏币 = 1ETH
0.1 游戏币 => 0.1 ether => 1e17

手续费：1%
最低下注手续费 1e15 --> 1 finney --> 0.001 ether

*/

contract Ownable {

    address private _owner;
    address private _croupier;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CroupiershipTransferred(address indexed previousCroupier, address indexed newCroupier);

    constructor() internal {
        _owner = msg.sender;
        _croupier = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
        emit CroupiershipTransferred(address(0), _croupier);
    }

    function owner() public view returns (address) {
        return _owner;
    }
    
    function croupier() public view returns (address) {
        return _croupier;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }
    
    modifier onlyCroupier() {
        require(msg.sender == _croupier, "Ownable: caller is not the croupier");
        _;
    }
    
    function transferCroupiership(address newCroupier) public onlyOwner {
        require(newCroupier != address(0), "Ownable: new croupier is the zero address");
        emit OwnershipTransferred(_croupier, newCroupier);
        _croupier = newCroupier;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}



contract roulette_royale is Ownable {
    
    struct Data {
        uint code;          // 下注编码
        uint amount;        // 下注金额
    }
    
    struct Bet {
        Data[] data;        // 下注信息
        address player;     // 玩家地址
        uint amount;        // 下注总金额
        uint random;        // 中奖号码
        uint bonus;         // 奖金
    }
    
    mapping(uint => Bet) private Bets;
    
    event CommitBet(uint);
    event CommitOpen(uint);
    
    uint[] private redlist      = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
    uint[] private blacklist    = [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];
    
    uint[] private line1        = [1,4,7,10,13,16,19,22,25,28,31,34];
    uint[] private line2        = [2,5,8,11,14,17,20,23,26,29,32,35];
    uint[] private line3        = [3,6,9,12,15,18,21,24,27,30,33,36];

    // 轮盘坐标，0起始顺时针
    uint[] private roulette     = [0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26];
    
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
                token -- token (项目方生成)
                data  -- 下注数据  ps: [[61, 1e15], [62, 2e15]]

    */
    function bet(uint token, Data[] memory data) public payable {

        Bet storage b = Bets[token];
        require (b.player == address(0), "Bet should be in a 'clean' state.");
        
        // 保存玩家 address
        b.player = msg.sender;

        // 下注总金额
        b.amount = 0;
        
        /*
            保存下注信息
            更新下注总金额
        */
        for (uint i = 0; i < data.length; i ++) {
            Data memory d = data[i];
            b.amount += d.amount;
            b.data.push(d);
        }

        require(b.amount > 100, "bet too large!");

        // 验证下注金额是否有效
        require(msg.value > 0 && msg.value >= b.amount, "insufficient fund!");
        
        // 通知 项目方 已经完成下注
        emit CommitBet(token);
    }
    
    /*
        随机数
         0 - 36 中的 一个
    */
    function create_random(uint token, uint random) private view returns (uint) {
        uint r = uint(keccak256(abi.encodePacked(block.difficulty, block.number, block.timestamp, now, token, random))) % 37;
        return r;
    }
    
    /*
        开奖
        
            只允许项目方指定的 address 调用
        
            params:
                token  -- token (项目方生成)
                random -- 随机码 (项目方开奖前生成)

    */
    function open(uint token, uint random) external onlyCroupier {
        
        Bet memory b = Bets[token];
        
        if (b.player != address(0)) {
            // 随机数
            b.random = create_random(token, random);
            
            // 计算奖金
            b.bonus = check(b);
            
            // 派奖
            if (b.bonus >= address(this).balance) {
                b.bonus = 0;
                b.player.transfer(b.amount);
            } else {
                if (b.bonus > 0) {
                    b.player.transfer(b.bonus);
                }
            }
        }
        
        emit CommitOpen(token);
    }

    /*
        查询开奖结果
        
            只允许 玩家 address 调用
        
            params:
                token  -- token (项目方生成)
                
            returns:
                uint  -- 奖金
    */
    function query(uint token) public view returns (uint) {
        Bet memory b = Bets[token];
        require (b.player == msg.sender, "caller is not the player!");
        return b.bonus;
    }
    
    /*
        中奖检测
            
            params:
                Bet  -- 下注信息
                
            returns:
                uint -- 奖金金额 (包含原始投注金额)
    */
    function check(Bet b) private view returns (uint) {
        uint amount = 0;
        
        for ( uint i = 0; i < b.data.length; i++ ) {
            Data memory d = b.data[i];
            amount += check(b.random, d);
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
    function check(uint random_number, Data d) public view returns (uint) {
        
        d.amount *= 1e17;
        
        uint i = 0;

        uint c = 0;
        
        uint amount = 0;
        
        uint x = random_number;
        
        // 手续费
        uint fee = (d.amount / 100);
        
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
        
        // 1/2 * 17   [low number] 例如 用户选择 0和1 那么 code = 241
        if (d.code == 241 && (x == 0 || x == 1)) amount += bv + (d.amount * 17);
        if (d.code == 242 && (x == 0 || x == 2)) amount += bv + (d.amount * 17);
        if (d.code == 243 && (x == 0 || x == 3)) amount += bv + (d.amount * 17);

        // 1/2 * 17   [low number] 例如 用户选择 1和2 那么 code = 201 横
        if (d.code > 200 && d.code < 240) {
            c = d.code - 200;
            if (x == c || x == c + 1) amount += bv + (d.amount * 17);
        }

        // 1/2 * 17   [low number] 例如 用户选择 1和4 那么 code = 251 竖
        if (d.code > 250 && d.code < 300) {
            c = d.code - 250;
            if (x == c || x == c + 3) amount += bv + (d.amount * 17);
        }
        
        // 1/3 * 11   [low number] 例如 用户选择 0和1和2 那么 code = 301
        if (d.code == 301 && (x == 0 || x == 1 || x == 2)) amount += bv + (d.amount * 11);
        if (d.code == 302 && (x == 0 || x == 2 || x == 3)) amount += bv + (d.amount * 11);
        
        // 1/4 * 8    [low number] 例如 选择了 1和2和4和5 那么 code = 401
        if (d.code > 400 && d.code < 500) {
            c = d.code - 400;
            if (x == c || x == (c + 1) || x == (c + 3) || x == (c + 4)) amount += bv + (d.amount * 8);
        }
        
        // 1/5 * 6    [mid number] 例如 选择了 0 那么 code = 500, 
        uint mid = 0;
        if (d.code >= 500 && d.code < 600) {
            c = d.code - 500;
            for (i = 0; i < roulette.length; i++ ) {
                if (roulette[i] == c) {
                    mid = i;
                    break;
                }
            }
            // 中
            if (x == c) amount += bv + (d.amount * 6);

            // 左2
            uint left2 = mid - 2;
            if (left2 < 0) left2 += roulette.length;
            if (x == roulette[left2]) amount += bv + (d.amount * 6);

            // 左1
            uint left1 = mid - 1;
            if (left1 < 0) left1 += roulette.length;
            if (x == roulette[left1]) amount += bv + (d.amount * 6);

            // 右1
            uint right1 = mid + 1;
            if (right1 >= roulette.length) right1 -= roulette.length;    
            if (x == roulette[right1]) amount += bv + (d.amount * 6);
            
            // 右2
            uint right2 = mid + 2;
            if (right2 >= roulette.length) right2 -= roulette.length;
            if (x == roulette[right2]) amount += bv + (d.amount * 6);
        }

        return (amount);
    }

}
