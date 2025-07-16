# Notion API Reference for NoBuddy

## Authentication
- Bearer token authentication
- Token stored securely in Keychain
- Rate limiting: 3 requests per second

## Endpoints Used

### Databases
- GET /v1/databases/{database_id}
- POST /v1/databases/{database_id}/query
- PATCH /v1/databases/{database_id}

### Pages
- GET /v1/pages/{page_id}
- POST /v1/pages
- PATCH /v1/pages/{page_id}

### Blocks
- GET /v1/blocks/{block_id}/children
- PATCH /v1/blocks/{block_id}
- DELETE /v1/blocks/{block_id}

### Search
- POST /v1/search

### Users
- GET /v1/users/me
- GET /v1/users
