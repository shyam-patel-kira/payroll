// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

interface IInstantDistributionAgreementV1 {
    function createIndex(
        IERC20 token,
        uint256 scale
    ) external;

    function deleteIndex(
        IERC20 token
    ) external;

    function updateIndex(
        IERC20 token
    ) external;

    function distribute(
        IERC20 token,
        uint256 amount,
        uint256 totalShares
    ) external;
}

contract Payroll {
    ISuperfluid private superfluid;
    IERC20 private superToken;
    IInstantDistributionAgreementV1 private instantDistributionAgreement;

    struct Employee {
        address employeeAddress;
        string name;
        uint256 age;
        uint256 salary;
        uint256 lastPaidAt;
    }

    mapping(address => Employee) public employees;

    event EmployeeRegistered(address indexed employee, uint256 salary, uint256 age, string name);
    event EmployeeSalaryChanged(address indexed employee, uint256 newSalary);
    event EmployeePaid(address indexed employee, uint256 amount);

    constructor(
        address _superfluid,
        address _superToken,
        address _instantDistributionAgreement
    ) {
        superfluid = ISuperfluid(_superfluid);
        superToken = IERC20(_superToken);
        instantDistributionAgreement = IInstantDistributionAgreementV1(
            _instantDistributionAgreement
        );
    }

    function registerEmployee(address employee, uint256 salary, uint256 age, string name) external {
        require(
            employees[employee].employeeAddress == address(0),
            "Employee already registered"
        );

        employees[employee] = Employee({
            employeeAddress: employee,
            salary: salary,
            name: name,
            age: age,
            lastPaidAt: block.timestamp
        });

        emit EmployeeRegistered(employee, salary);
    }

    function updateEmployeeSalary(address employee, uint256 newSalary)
        external
    {
        require(
            employees[employee].employeeAddress != address(0),
            "Employee not registered"
        );

        employees[employee].salary = newSalary;

        emit EmployeeSalaryChanged(employee, newSalary);
    }

    function payEmployee(address employee) external {
        Employee storage emp = employees[employee];
        require(emp.employeeAddress != address(0), "Employee not registered");

        uint256 elapsedTime = block.timestamp - emp.lastPaidAt;
        uint256 amount = elapsedTime * emp.salary;

        // Update last paid timestamp
        emp.lastPaidAt = block.timestamp;

        // Transfer salary in SuperTokens
        superToken.transfer(employee, amount);

        // Distribute the remaining balance to other shareholders
        instantDistributionAgreement.distribute(
            superToken,
            amount,
            superToken.balanceOf(address(this))
        );

        emit EmployeePaid(employee, amount);
    }
}
