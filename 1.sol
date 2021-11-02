// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts@4.3.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.3.2/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.3.2/security/Pausable.sol";
import "@openzeppelin/contracts@4.3.2/access/AccessControl.sol";
import "@openzeppelin/contracts@4.3.2/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
/*12313
*/
contract THE9TEST is ERC20, Pausable, AccessControl {
    uint256 constant DEFAULT_RELEASE_TIMESTAMP = 4102412400; // 2100년 1월 1일 금요일 오전 12:00:00 GMT+09:00
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ORG_ADMIN_ROLE = keccak256("ORG_ADMIN_ROLE");

    struct BeneficiaryInfo {
        uint256 amount;
        uint256 releaseTime;
        uint256 remainPercent;
        uint256 remainAmount;
    }

    mapping(address => BeneficiaryInfo) private _addressBeneficiaryInfo;
    address[] public Beneficiaries;

    constructor() ERC20("THE9TEST", "THE9TEST") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
        _setupRole(ORG_ADMIN_ROLE, _msgSender());
        _mint(_msgSender(), 10000 * 10 ** decimals());
    }

    event CreateAmountWithLock(address beneficiary, BeneficiaryInfo beneficiaryInfo);
    event UpdateAmountWithLock(address beneficiary, uint256 amount, uint256 releaseTime, BeneficiaryInfo beneficiaryInfo);
    event TransferAmountWithLock(address beneficiary, uint256 amount, BeneficiaryInfo beneficiaryInfo);

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function createAmountWithLock(address beneficiary, uint256 amount, uint256 releaseTime)
        public
        whenNotPaused
        onlyRole(ORG_ADMIN_ROLE) 
    {
        require(beneficiary != address(0), "beneficiary from the zero address");

        if (releaseTime == 0) {
            releaseTime = DEFAULT_RELEASE_TIMESTAMP;
        }
        require(releaseTime > block.timestamp, "release time is before current time");

        if (_checkExists(beneficiary)) {
            updateAmountWithLock(beneficiary, amount, releaseTime);
        } else {
            _setBeneficiaryInfo(beneficiary, _calcDecimal(amount), releaseTime, 100, _calcDecimal(amount));
            Beneficiaries.push(beneficiary);

            emit CreateAmountWithLock(beneficiary, _addressBeneficiaryInfo[beneficiary]);
        }
    }

    function updateAmountWithLock(address beneficiary, uint256 amount, uint256 releaseTime)
        public
        whenNotPaused
        onlyRole(ORG_ADMIN_ROLE) 
    {
        require(beneficiary != address(0), "beneficiary from the zero address");
        require(_checkExists(beneficiary), "beneficiary not found");

        if (releaseTime == 0) {
            releaseTime = DEFAULT_RELEASE_TIMESTAMP;
        }
        require(releaseTime > block.timestamp, "release time must be after the current time");
        require(_addressBeneficiaryInfo[beneficiary].remainPercent >= 100, "account to which revenue was transferred");

        BeneficiaryInfo storage beforeInfo = _addressBeneficiaryInfo[beneficiary];
        _setBeneficiaryInfo(beneficiary, _calcDecimal(amount), releaseTime, 100, _calcDecimal(amount));

        emit UpdateAmountWithLock(beneficiary, amount, releaseTime, beforeInfo);
    }

    function transferAmountWithLock(address beneficiary, uint256 percentage)
        public
        onlyRole(ORG_ADMIN_ROLE) 
    {
        require(beneficiary != address(0), "beneficiary from the zero address");
        require(percentage > 0, "percentage cannot be zero");
        require(percentage <= 100, "percentage cannot exceed 100");

        // check exists
        require(_checkExists(beneficiary), "beneficiary not found");

        // check timestamp
        BeneficiaryInfo storage beforeInfo = _addressBeneficiaryInfo[beneficiary];
        require(block.timestamp >= beforeInfo.releaseTime, "current time is cefore release time");

        // remainAmount
        uint256 remainAmount = beforeInfo.remainAmount;

        // check Oranization
        uint256 totalOrgAmount = balanceOf(_msgSender());
        require(totalOrgAmount > 0, "Organization account does not have token holdings");

        // check holding token
        uint256 transferAmount = SafeMath.div(SafeMath.mul(beforeInfo.amount, percentage), 100);
        require(totalOrgAmount >= transferAmount, "exceeding the ortanization's holdings");

        _beforeTokenTransfer(_msgSender(), beneficiary, transferAmount);

        transfer(beneficiary, transferAmount);

        uint256 afterRemainAmount = SafeMath.sub(remainAmount, transferAmount);
        _setBeneficiaryInfo(beneficiary, beforeInfo.amount, beforeInfo.releaseTime, SafeMath.sub(beforeInfo.remainPercent, percentage), afterRemainAmount);

        super._afterTokenTransfer(_msgSender(), beneficiary, transferAmount);
        emit TransferAmountWithLock(beneficiary, transferAmount, _addressBeneficiaryInfo[beneficiary]);
    }

    function getBeneficiaryInfo(address beneficiary) 
        public 
        view 
        returns(BeneficiaryInfo memory) 
    {
        require(beneficiary != address(0), "beneficiary from the zero address");
        return _addressBeneficiaryInfo[beneficiary];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _setBeneficiaryInfo(address beneficiary, uint256 amount, uint256 releaseTime, uint256 remainPercent, uint256 remainAmount) 
        internal 
    {
        _addressBeneficiaryInfo[beneficiary].amount = amount;
        _addressBeneficiaryInfo[beneficiary].releaseTime = releaseTime;
        _addressBeneficiaryInfo[beneficiary].remainPercent = remainPercent;
        _addressBeneficiaryInfo[beneficiary].remainAmount = remainAmount;
    }

    function _releaseTime(address beneficiary) 
        internal 
        view 
        returns(uint256) 
    {
        if (_checkExists(beneficiary)) {
            return _addressBeneficiaryInfo[beneficiary].releaseTime;
        } else {
            return 0;
        }
    }

    function _checkExists(address beneficiary) 
        internal 
        view 
        returns(bool) 
    {
        if (_addressBeneficiaryInfo[beneficiary].amount > 0) {
            return true;
        } else {
            return false;
        }
    }
    
    function _calcDecimal(uint256 amount) 
        internal 
        view 
        returns(uint256)
    {
        return amount * 10 ** decimals();
    }
}