# Quiz Editor Implementation Summary

## Overview
A fully functional Quiz Editor has been implemented for the admin dashboard, allowing administrators to manage questions within question banks. The feature supports CRUD operations (Create, Read, Update, Delete) for questions with comprehensive validation and error handling.

## What Was Built

### 1. Backend API Endpoints (`backend/app/api/v1/endpoints/admin.py`)

Five new admin-only endpoints for managing questions:

```
GET    /admin/question-banks/{bank_id}/questions
POST   /admin/question-banks/{bank_id}/questions
PUT    /admin/questions/{question_id}
PATCH  /admin/questions/{question_id}/toggle
DELETE /admin/questions/{question_id}
```

**Features:**
- Full pagination support (page, page_size, has_next, has_prev)
- Soft-delete capability (toggle between active/inactive)
- Question filtering options
- Role-based access control (admin-only)

### 2. Backend Schemas (`backend/app/schemas/admin.py`)

New Pydantic models for request/response validation:

- `QuestionCreate` - Payload for creating questions
- `QuestionUpdate` - Payload for updating questions
- `AdminQuestionSummary` - Question detail for list endpoints
- `AdminQuestionListResponse` - Paginated response
- `QuestionToggleResponse` - Toggle action response

### 3. Flutter Service (`frontend/lib/services/admin_question_service.dart`)

`AdminQuestionService` class providing:

- **Models:**
  - `AdminQuestion` - Question data model with helper methods
  - `AdminQuestionListResponse` - Paginated list response
  
- **Methods:**
  - `fetchQuestions()` - Load paginated question list
  - `createQuestion()` - Create new question
  - `updateQuestion()` - Update existing question
  - `toggleQuestion()` - Enable/disable question
  - `deleteQuestion()` - Soft-delete question
  - `clear()` - Reset service state

- **Features:**
  - Bearer token authentication
  - Error handling and user-friendly messages
  - ChangeNotifier for reactive UI updates
  - Loading/error state management

### 4. Admin Quiz Editor UI (`frontend/lib/features/admin/presentation/pages/admin_quiz_editor_page.dart`)

**Main Page Features:**
- Display list of question banks as selectable chips
- Load questions from selected bank
- Create, edit, toggle, and delete questions
- Real-time statistics (total, active, inactive questions)
- Pagination support
- Refresh on pull-to-refresh
- Comprehensive error handling and empty states

**Components:**

1. **`_QuestionFormDialog`** - Modal for creating/editing questions
   - Question content text area
   - Dynamic choice fields (A, B, C, D)
   - Radio button to select correct answer
   - Form validation before submission

2. **`_QuestionRow`** - Question display card
   - Question ID and status badge
   - Question content preview
   - Choice display with visual indicator for correct answer
   - Edit, toggle, and delete action buttons

3. **`_StatCard`** - Statistics display widget
   - Shows total, active, and inactive question counts
   - Color-coded for quick visual reference

## Features Implemented

### ✅ Display Question List
- Questions shown by selected question bank
- Paginated display (default 20 per page)
- Show question number, content, choices, and correct answer
- Visual status indicator (Active/Inactive)

### ✅ Create Question
- Modal form with validation
- Required fields: content, all choices, correct answer
- Real-time UI update after creation
- Success notification

### ✅ Edit Question Content
- Modal form populated with existing data
- Edit content, choices, or correct answer
- Validation before submission
- Success notification

### ✅ Edit Answer List
- Update individual choice values
- Change which choice is correct answer
- Visual confirmation of correct answer selection

### ✅ Select Correct Answer
- Radio buttons for easy selection
- Visual indicator showing selected answer
- Mark correct answer after editing

### ✅ Delete/Disable Questions
- Two separate operations:
  - Toggle: Disable/enable question (PATCH)
  - Delete: Permanent soft-delete (DELETE)
- Confirmation dialogs for destructive actions
- Real-time UI update

### ✅ Form Validation
- Question content required and non-empty
- All choice fields required
- Correct answer must be selected
- Display validation errors to user

## User Workflow

### Creating a Question
1. Navigate to Admin → Quiz Editor
2. Select a question bank from the chips
3. Click "Thêm câu hỏi" button
4. Fill in question content
5. Enter all 4 answer choices (A, B, C, D)
6. Select the correct answer using radio button
7. Click "Lưu" to save

### Editing a Question
1. Click "Sửa" button on the question card
2. Modal opens with pre-filled data
3. Update content, choices, or correct answer as needed
4. Click "Lưu" to save changes

### Managing Question Status
- **Disable:** Click "Vô hiệu hóa" → question becomes inactive but not deleted
- **Enable:** Click "Kích hoạt" → reactivate disabled question
- **Delete:** Click "Xóa" → permanently remove question (with confirmation)

## API Contract Examples

### Create Question
```bash
POST /admin/question-banks/1/questions
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "What is the capital of France?",
  "choices": {
    "A": "Paris",
    "B": "London",
    "C": "Berlin",
    "D": "Madrid"
  },
  "correct_answer": "A"
}
```

### Update Question
```bash
PUT /admin/questions/5
Authorization: Bearer <token>
Content-Type: application/json

{
  "content": "What is the capital of France?",
  "choices": {
    "A": "Paris",
    "B": "Lyon",
    "C": "Berlin",
    "D": "Madrid"
  },
  "correct_answer": "A"
}
```

### Toggle Question Status
```bash
PATCH /admin/questions/5/toggle
Authorization: Bearer <token>
```

### Delete Question
```bash
DELETE /admin/questions/5
Authorization: Bearer <token>
```

## Integration Points

### Router
- Route: `/admin/quiz-editor`
- Integrated in `lib/core/router/admin_router.dart`
- Navigation item in admin layout sidebar

### Admin Layout
- Label: "Trình soạn bài kiểm tra" (Quiz Editor)
- Icon: Icons.quiz_rounded
- Accessible from sidebar/drawer

## Data Models

### Question Structure (Database)
```python
{
  "id": 1,
  "bank_id": 1,
  "content": "Question text",
  "choices": {"A": "Choice A", "B": "Choice B", ...},
  "correct_answer": "A",
  "is_deleted": false,
  "created_at": "2026-05-31T...",
  "updated_at": "2026-05-31T..."
}
```

## Error Handling

**Backend:**
- 401: Unauthorized (missing/invalid token)
- 403: Forbidden (non-admin user)
- 404: Question or bank not found
- 400: Invalid input data

**Frontend:**
- Toast notifications for errors
- Snackbars for success/error messages
- Error state UI when API calls fail
- Graceful loading states

## Security

- All endpoints require admin authentication
- Bearer token in Authorization header
- Database-level role verification
- Soft-delete prevents data loss
- Input validation on both client and server

## Testing Checklist

- [x] Can select question bank
- [x] Can load questions from selected bank
- [x] Can create new question with validation
- [x] Can edit existing question
- [x] Can change correct answer
- [x] Can disable/enable question
- [x] Can delete question with confirmation
- [x] Pagination works correctly
- [x] Error messages display properly
- [x] Loading states show during API calls
- [x] Success notifications appear
- [x] Empty states display correctly

## Future Enhancements

1. **Bulk Operations**
   - Select multiple questions
   - Bulk delete/toggle

2. **Advanced Filtering**
   - Filter by creation date
   - Filter by difficulty level
   - Filter by tags

3. **Question Preview**
   - Preview how question looks for users
   - Test answer logic

4. **Import/Export**
   - Import questions from CSV/Excel
   - Export questions to CSV

5. **Question History**
   - Track question edits
   - Rollback to previous versions

## File Locations

| Component | Path |
|-----------|------|
| Backend Endpoints | `backend/app/api/v1/endpoints/admin.py` |
| Backend Schemas | `backend/app/schemas/admin.py` |
| Flutter Service | `frontend/lib/services/admin_question_service.dart` |
| Quiz Editor Page | `frontend/lib/features/admin/presentation/pages/admin_quiz_editor_page.dart` |
| Admin Router | `frontend/lib/core/router/admin_router.dart` |
| Admin Layout | `frontend/lib/features/admin/presentation/layout/admin_layout.dart` |
