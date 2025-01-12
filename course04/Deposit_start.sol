// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "./WETH.sol";
import "./SafeMath.sol";

contract DepositContract {
    using SafeMath for uint256;

    address payable public immutable _weth;     // 替换为自己部署的 WETH 地址
    uint256 public constant rewardBase = 5;     // 每5个币经过一个区块，可以领取1个ETH奖励。注意这里的奖励是ETH而不是WETH；
    uint256 public immutable startBlock;        // 在构造函数中定义
    uint256 public immutable endBlock;          // 在构造函数中定义

    mapping(address => uint256) public depositAmount;       // 用户的存款总量
    mapping(address => uint256) public checkPoint;          // 每次存款或提取本金时，更新这个值
    mapping(address => uint256) public calculatedReward;    // 已经计算的利息
    mapping(address => uint256) public claimedReward;       // 已经提取的利息

    event Deposit(address indexed sender, uint256 amount);
    event Claim(address indexed sender, address recipient, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);

    constructor(address payable _wethAddress, uint256 _period) {
        // period 为从当前开始，延续多少个区块
        startBlock = block.number;
        endBlock = block.number + _period + 1;
        _weth = _wethAddress;
    }
    // 修饰符，充值时只允许在设定的区块范围内
    modifier onlyValidTime() {
        require( 
            block.number >= startBlock && block.number <= endBlock,"out of the range"            
        );
        _;
    }
    /**
     * @dev 存钱到合约
     * 如果是第一次存钱，calculatedReward的数值为0
     * 如果不是第一次存钱，应当计算经过前几个区块后的利息，记录到calculatedReward中，方便后续利息的计算。
     */
    function deposit(uint256 _amount) public onlyValidTime returns (bool) {
        if(depositAmount[msg.sender] != 0){
            calculatedReward[msg.sender]=calculatedReward[msg.sender].add(block.number.sub(checkPoint[msg.sender].div(depositAmount[msg.sender])).mul(depositAmount[msg.sender]).div(rewardBase));
        }

        WETH(_weth).transferFrom(msg.sender,address(this),_amount);
        depositAmount[msg.sender]  = depositAmount[msg.sender].add(_amount);
        checkPoint[msg.sender] = depositAmount[msg.sender].mul(block.number);

        emit Deposit(msg.sender, _amount);
        return true;
    }

    // 查询利息
    function getPendingReward(address _account)
        public
        view
        returns (uint256 pendingReward)
    {
        uint time = block.number > endBlock ? endBlock : block.number;
        pendingReward = calculatedReward[_account].add(time.sub(checkPoint[_account].div(depositAmount[_account])).mul(depositAmount[_account]).div(rewardBase))-claimedReward[_account]; 
    }

    // 领取利息
    function claimReward(address payable _toAddress) public returns (bool) {
        uint pendingReward = getPendingReward(msg.sender);                          // 通过pendingReward函数获得用户待领取的利息
        WETH(_weth).withdrawTo(_toAddress,pendingReward);                           // 调用withdraw提取
        claimedReward[msg.sender] = claimedReward[msg.sender].add(pendingReward);   // 领取利息后对claimedReward累加
        emit Claim(msg.sender, _toAddress, pendingReward);
        return true;
    }
    
    // 提取一定数量的本金
    function withdraw(uint256 _amount) public returns (bool) {
        claimReward(payable(msg.sender));
        require(
            // 提取的本金应当小于等于存款总额
            depositAmount[msg.sender]>=_amount,"have no enough memory"
        );

        uint time = block.number > endBlock ? endBlock : block.number;
        calculatedReward[msg.sender]=calculatedReward[msg.sender].add(time.sub(checkPoint[msg.sender].div(depositAmount[msg.sender])).mul(depositAmount[msg.sender]).div(rewardBase));

        WETH(_weth).withdrawTo(msg.sender,_amount);                             // 调用withdrawto进行提取
        depositAmount[msg.sender] = depositAmount[msg.sender].sub(_amount);     // 提取后本金减少
        checkPoint[msg.sender] = depositAmount[msg.sender].mul(block.number);        
        emit Withdraw(msg.sender, _amount);
        return true;
    }

    // 以下不用改
    // 用于在Remix本地环境中增加区块高度
    uint256 counter;

    function addBlockNumber() public {
        counter++;
    }

    // 获取当前区块高度
    function getBlockNumber() public view returns (uint256) {
        return block.number;
    }
}
