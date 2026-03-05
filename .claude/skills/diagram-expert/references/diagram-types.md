# Diagram Type Examples

Full D2 code examples and detailed guidance for common diagram types.

## Example 1: Simple Flowchart

User says: "Create a flowchart showing user login flow."

```d2
direction: down

start: User opens app { shape: oval }
input: Enter credentials { shape: rectangle }
validate: Validate credentials { shape: diamond }
success: Dashboard { shape: rectangle }
failure: Show error { shape: rectangle }

start -> input -> validate
validate -> success: valid
validate -> failure: invalid
failure -> input: retry
```

Render command: `d2 login-flow.d2 <output-path>/login-flow.svg`

## Example 2: Microservices Architecture Diagram

User says: "Draw an architecture diagram for a microservices system with API
gateway, auth service, user service, and PostgreSQL."

```d2
direction: right

client: Client { shape: person }

gateway: API Gateway {
  shape: hexagon
}

services: Backend Services {
  auth: Auth Service {
    shape: rectangle
  }
  users: User Service {
    shape: rectangle
  }
}

data: Data Layer {
  postgres: PostgreSQL {
    shape: cylinder
  }
}

client -> gateway: "HTTPS"
gateway -> services.auth: "gRPC"
gateway -> services.users: "gRPC"
services.auth -> data.postgres: "SQL"
services.users -> data.postgres: "SQL"
```

Render command: `d2 --layout elk architecture.d2 <output-path>/architecture.svg`

## Example 3: OAuth2 Sequence Diagram

User says: "Create a sequence diagram showing OAuth2 authorization code flow."

```d2
oauth: OAuth2 Authorization Code Flow {
  shape: sequence_diagram

  user: User
  app: Client App
  auth: Auth Server
  api: Resource Server

  user -> app: Click "Login"
  app -> auth: Redirect to /authorize
  auth -> user: Show consent screen
  user -> auth: Grant permission
  auth -> app: Authorization code
  app -> auth: Exchange code for token
  auth -> app: Access token + Refresh token
  app -> api: Request with access token
  api -> app: Protected resource
}
```

Render command: `d2 oauth-flow.d2 <output-path>/oauth-flow.svg`

## Connection Types Reference

| Syntax | Meaning |
|--------|---------|
| `a -> b` | Unidirectional |
| `a <-> b` | Bidirectional |
| `a -- b` | Undirected association |
| `a -> b: "label"` | Labeled connection |

## Shape Selection Guide

| Concept | Shape |
|---------|-------|
| Database / storage | `cylinder` |
| Message queue / broker | `queue` |
| Cloud provider / region | `cloud` |
| External system | `hexagon` |
| Module / package | `package` |
| User / actor | `person` |
| Start / end of flow | `oval` |
| Decision / branch | `diamond` |
| Document / page | `page` |

## Container Nesting Guide

Containers represent logical boundaries such as services, layers, and domains.

```d2
# Two-level nesting: domain > service
backend: Backend {
  api: API Layer {
    gateway: API Gateway { shape: hexagon }
    router: Router
  }
  logic: Business Logic {
    orders: Order Service
    payments: Payment Service
  }
}

# Cross-container connections use dot notation
backend.api.gateway -> backend.logic.orders: "POST /order"
```

## Theme Reference

| Theme ID | Name |
|----------|------|
| 0 | Default |
| 1 | Neutral Grey |
| 3 | Origami |
| 4 | Flagship Terrastruct |
| 100 | Terminal |
| 200 | Dark Maelstrom |
| 300 | Grape Soda |
