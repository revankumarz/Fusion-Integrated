# ELM Module Architecture Overview

## Models and Their Fields

### LeaveType
- **Fields**: 
  - `code`: Unique identifier for the leave type.
  - `name`: Name of the leave type.
  - `max_days_per_year`: Maximum number of days allowed per year for this leave type.
  - `requires_document`: Boolean indicating if a document is required for this leave type.
  - `is_active`: Boolean indicating if the leave type is active.

### LeaveBalance
- **Fields**: 
  - `employee_id`: ID of the employee.
  - `leave_type`: Foreign key to the `LeaveType` model.
  - `year`: Year for which the balance is calculated.
  - `allotted`: Total days allotted for this leave type in the specified year.
  - `used`: Total days used for this leave type in the specified year.

### LeaveApplication
- **Fields**: 
  - `employee_id`: ID of the employee who applied for leave.
  - `leave_type`: Foreign key to the `LeaveType` model.
  - `start_date`: Start date of the leave period.
  - `end_date`: End date of the leave period.
  - `days`: Total number of days requested for leave.
  - `reason`: Reason for applying for leave.
  - `status`: Current status of the leave application (DRAFT, SUBMITTED, APPROVED, REJECTED, CANCELLED).
  - `approver_id`: ID of the approver if the application is in a pending state.
  - `remarks`: Additional remarks related to the application.
  - `decided_at`: Timestamp when the application was decided.

## Service Functions

### apply
- **Purpose**: Allows an employee to apply for leave.
- **Parameters**:
  - `actor`: The user making the request.
  - `leave_type_id`: ID of the leave type.
  - `start_date`: Start date of the leave period.
  - `end_date`: End date of the leave period.
  - `reason`: Reason for applying for leave.
- **Returns**: The created `LeaveApplication` object.

### decide
- **Purpose**: Approves or rejects a leave application.
- **Parameters**:
  - `actor`: The user making the request.
  - `application_id`: ID of the leave application to be decided.
  - `approve`: Boolean indicating whether to approve or reject the application.
  - `remarks`: Additional remarks related to the decision.
- **Returns**: The updated `LeaveApplication` object.

### withdraw
- **Purpose**: Withdraws a pending leave application.
- **Parameters**:
  - `actor`: The user making the request.
  - `application_id`: ID of the leave application to be withdrawn.
- **Returns**: The updated `LeaveApplication` object.

### cancel_approved
- **Purpose**: Cancels an approved leave application that has not yet started.
- **Parameters**:
  - `actor`: The user making the request.
  - `application_id`: ID of the leave application to be cancelled.
- **Returns**: The updated `LeaveApplication` object.

## API Endpoints

### LeaveTypeListView
- **Method**: GET
- **URL**: `/leave/types`
- **Permission**: None (public)
- **Description**: Lists all available leave types.

### MyApplicationsView
- **Method**: GET
- **URL**: `/leave/applications`
- **Permission**: `leave_elm.application.view`
- **Description**: Lists applications made by the current user.

### PendingApprovalsView
- **Method**: GET
- **URL**: `/leave/applications/pending`
- **Permission**: `leave_elm.application.approve`
- **Description**: Lists pending leave applications for approval.

### DecideView
- **Method**: POST
- **URL**: `/leave/applications/<int:pk>/decide`
- **Permission**: `leave_elm.application.approve`
- **Description**: Approves or rejects a specific leave application.

### WithdrawView
- **Method**: POST
- **URL**: `/leave/applications/<int:pk>/withdraw`
- **Permission**: `leave_elm.application.withdraw`
- **Description**: Withdraws a pending leave application made by the current user.

### CancelView
- **Method**: POST
- **URL**: `/leave/applications/<int:pk>/cancel`
- **Permission**: `leave_elm.application.cancel`
- **Description**: Cancels an approved leave application that has not yet started.

### MyBalanceView
- **Method**: GET
- **URL**: `/leave/balance`
- **Permission**: `leave_elm.balance.view`
- **Description**: Retrieves the current leave balance for the current user.

## Roles and Permissions

### ROLE_GRANTS
- **Employee**: Can view and apply for leave.
- **Leave Approver**: Can view, approve, and reject leave applications.
- **Leave Admin**: Can manage leave policies and view balances.

## Mapping to ELM Use Cases

| UC-001 Apply for leave | Implemented |
|-----------------------|-------------|
| UC-002 Respond to substitute request | Missing |
| UC-003 Unit Head review | Partial (only approval/rejection) |
| UC-004 Verify/route higher-sanction | Missing |
| UC-005 Final sanctioning decision | Implemented |
| UC-007 Withdraw pending application | Implemented |
| UC-008 Cancel approved leave | Implemented |
| UC-009 Extension | Missing |
| UC-010/011 Resumption | Missing |
| UC-012 View balances/history | Implemented |
| UC-013 Printable application | Missing |
| UC-014 Policy/hierarchy configuration | Missing |
| UC-015 Holiday calendar | Missing |
| UC-020 Year-end processing | Missing |

## Incomplete/Inconsistent Items

- **Permissions**: 
  - `leave_elm.application.approve` is used in the code but not declared.
  - `leave_elm.balance.view` is used in the code but not declared.

