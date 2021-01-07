pragma solidity ^0.4.23;
pragma experimental ABIEncoderV2;

/*

1:1 比例 
1个游戏币 = 1ETH
0.1 游戏币 => 0.1 ether => 1e17

最小下注 0.1 游戏币, 调用合约时金额必须是整数, 所以 0.1 游戏币 下注时 bet.amount = 1 , 以此类推 1游戏币下注时 bet.amount = 10

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
    
    mapping(string => Bet) private Bets;
    
    event CommitBet(string);
    event CommitOpen(string);
    
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
    function bet(string token, Data[] memory data) public payable {

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
            b.amount += (d.amount * 1e17);
            b.data.push(d);
        }

        require(b.amount < 1e20, "bet too large!");

        // 验证下注金额是否有效
        require(msg.value > 0 && msg.value >= b.amount, "insufficient fund!");
        
        // 通知 项目方 已经完成下注
        emit CommitBet(token);
    }
    
    /*
        随机数
         0 - 36 中的 一个
    */
    function create_random(string token, string random) public view returns (uint) {
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
    function open(string token, string random) external onlyCroupier {
        
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
    function query(string token) public view returns (uint) {
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
    function check(Bet b) private pure returns (uint) {
        uint amount = 0;
        
        for ( uint i = 0; i < b.data.length; i++ ) {
            Data memory d = b.data[i];
            amount += check(b.random, d.code, d.amount);
        }
        
        return amount;
    }
    
    /*
        中奖检测
        
            params:
                random  -- 随机数
                code    -- 下注编码
                amount  -- 下注金额
                
            returns:
                uint  -- 奖金金额 (包含下注净值)
            
    */
    function check(uint random, uint code, uint amount) private pure returns (uint) {
        
        uint r = random;
        uint c = code;
        uint a = amount * 1e17;
        
        // single number
        if (c >= 0 && c < 37) return check_single(r, c, a);
        
        // even or odd
        if (c > 40 && c < 43) return check_even_odd(r, c, a);
        
        // red or black
        if (c > 50 && c < 53) return check_red_black(r, c, a);

        // small[1-18] or big[18-36]
        if (c > 60 && c < 63) return check_small_big(r, c, a);
        
        // 3 group
        if (c > 70 && c < 74) return check_group(r, c, a);

        // 3 line
        if (c > 80 && c < 84) return check_line(r, c, a);
        
        // 2 option
        if (c >= 200 && c <= 299) return check_2(r, c, a);
        
        // 3 option
        if (c >= 301 && c <= 302) return check_3(r, c, a);
        
        // 4 option
        if (c >= 401 && c <= 432) return check_4(r, c, a);
        
        // 5 option
        if (c >= 500 && c <= 536) return check_5(r, c, a);
        
        return 0;
    }
    
    /*
        扣手续费 1%
    */
    function net_value(uint a)  private pure returns (uint) {
        if (a < 100) return 0;
        return (a - (a / 100));
    }
    
    /*
        单数字
        
        35倍
    */
    function check_single(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c > 36) return 0;
        
        uint v = net_value(a);
        
        uint w = v + (a * 35);
        
        if (c == r) return w;
        
        return 0;
    }
    
    /*
        奇数 偶数
        
        1倍
    */
    function check_even_odd(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 41 || c > 42 ) return 0;
        
        uint x = c - 40;
        
        if (x == 2) x = 0;
        
        uint v = net_value(a);
        
        uint w = v + a;
        
        if (r % 2 == x) return w;
        
        return 0;
    }
    
    /*
        红 黑
        
        1倍
    */
    function check_red_black(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 51 || c > 52 ) return 0;
        
        uint v = net_value(a);
        
        uint w = v + a;
        
        uint i;
        
        uint8[18] memory red = [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36];
        
        if (c == 51) {
            for (i = 0; i < red.length; i++ ) {
                if (red[i] == r) {
                    return w;
                }
            }
        }

        uint8[18] memory black = [2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35];
        
        if (c == 52) {
            for (i = 0; i < black.length; i++ ) {
                if (black[i] == r) {
                    return w;
                }
            }
        }
        
        return 0;
    }
    
    /*
        大 小
        
        1倍
    */
    function check_small_big(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 61 || c > 62) return 0;
        
        uint x = c - 60;
        
        uint v = net_value(a);
        
        uint w = v + a;

        if ((x * 18) >= r || r >= ((x * 18) - 17)) return w;
        
        return 0;
    }
    
    /*
        group 3
        
        2倍
    */
    function check_group(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 71 || c > 73) return 0;
        
        uint x = c - 70;
        
        uint v = net_value(a);
        
        uint w = v + (a * 2);
        
        if (r >=  x * 12 - 11 && r <= x * 12) return w;

        return 0;
    }
    
    /*
        line 3
        
        2倍
    */
    function check_line(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 81 || c > 83) return 0;
        
        uint x = c - 80;
        
        uint v = net_value(a);
        
        uint w = v + (a * 2);
        
        for (uint i = x; i < 37; i += 3 ) {
            if (i == r) return w;
        }

        return 0;
    }
    
    /*
        option 2
        
        17倍
    */
    function check_2(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 200 || c > 300) return 0;
        
        uint x = c - 200;
        
        uint v = net_value(a);
        
        uint w = v + (a * 17);
        
        if (x >= 1 && x <= 36){
            if (r == x || r == x + 1) return w;                 // 1 2 组队
        }
        
        if (x >= 41 && x <= 76) {
            if (r == (x - 40) || r == (x - 40 + 3)) return w;   // 1 4 组队
        }
        
        if (x >= 91 && x <= 93) {
            if (r == 0 || r == (x - 90)) return w;              // 0 与 [1,2,3] 组队
        }

        return 0;
    }
    
    /*
        option 3
        
        0 1 2
        
        0 2 3
        
        11倍
    */
    function check_3(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 301 || c > 302) return 0;
        
        uint x = c - 300;
        
        uint v = net_value(a);
        
        uint w = v + (a * 11);
        
        if (r == 0 || r == x || r == (x + 1)) return w;
        
        return 0;
    }
    
    /*
        option 4
        
        8倍
    */
    function check_4(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 401 || c > 432) return 0;
        
        uint x = c - 400;
        
        for (uint i = 3; i < 32; i += 3 ) {
            if (i == x) return 0;
        }
        
        uint v = net_value(a);
        
        uint w = v + (a * 8);
        
        if (r == c || r == (c + 1) || r == (c + 3) || r == (c + 4)) return w;
        
        return 0;
    }
    
    /*
        option 5
       
        [0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26]
       
        params:
            r    ==> random number
            c    ==> bet code
            a    ==> bet amount
            
        returns:
            uint ==> bonus amount
            
        6倍
    */
    function check_5(uint r, uint c, uint a) private pure returns (uint) {
        
        if (c < 500 || c > 536) return 0;
        
        uint x = c - 500;
        
        uint v = net_value(a);
        
        uint w = v + (a * 6);
        
        if (x == r) return w;
        
        uint i;
        uint j;

        uint8[37] memory o = [0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26];

        for (i = 0; i < o.length; i++ ) {
            if (o[i] == x) {
                break;
            }
        }

        uint[4] memory k = [o.length + i - 2, o.length + i - 1, i + 1, i + 2];

        for (j = 0; j < k.length; j++) {
            uint n = k[j];
            if (n >= o.length) n -= o.length;
            if (r == o[n]) return w;
        }

        return 0;
    }

}
