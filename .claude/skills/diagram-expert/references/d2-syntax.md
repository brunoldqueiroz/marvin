# D2 Quick Reference

## Basic Syntax

```d2
# Node declaration
server: Web Server

# Connection
server -> db

# Labeled connection
server -> db: "SQL queries"

# Container (grouping)
cloud: AWS {
  ec2: EC2 Instance
  rds: RDS PostgreSQL { shape: cylinder }
  ec2 -> rds
}

# Direction
direction: down  # down | right | left | up
```

## Shapes

```d2
# Available shapes
rect: Rectangle                          # default
oval: Start { shape: oval }
diamond: Decision { shape: diamond }
cylinder: Database { shape: cylinder }
queue: Message Queue { shape: queue }
cloud: Cloud Provider { shape: cloud }
person: User { shape: person }
hexagon: External { shape: hexagon }
package: Module { shape: package }
page: Document { shape: page }
circle: Node { shape: circle }
```

## Styling

```d2
# Inline style
server: Web Server {
  style: {
    fill: "#e1f5fe"
    stroke: "#0288d1"
    border-radius: 8
    font-size: 16
    bold: true
  }
}

# Connections style
a -> b: label {
  style: {
    stroke: red
    stroke-dash: 5
    animated: true
  }
}
```

## Sequence Diagrams

```d2
diagram: Title {
  shape: sequence_diagram
  actor1: Actor 1
  actor2: Actor 2
  actor1 -> actor2: message
  actor2 -> actor1: response
  actor1 -> actor1: self-call
}
```

## Advanced Features

```d2
# Multiple boards via layers
layers: {
  overview: { ... }
  detail: { ... }
}

# Grid layout
grid: {
  grid-columns: 3
  a; b; c; d; e; f
}

# Tooltip and link
node: Clickable {
  tooltip: "Extra details shown on hover"
  link: "https://example.com"
}

# Icon
aws: AWS {
  icon: https://icons.terrastruct.com/aws/_Group%20Icons/Cloud-alt_light-bg.svg
}

# Classes (reusable styles)
classes: {
  service: {
    style.fill: "#e8f5e9"
    style.stroke: "#2e7d32"
    shape: rectangle
  }
}
node1.class: service
node2.class: service

# Sketch mode (via CLI flag)
# d2 --sketch input.d2 output.svg
```

## CLI Commands

```bash
# Format/validate
d2 fmt diagram.d2

# Render SVG (default)
d2 diagram.d2 output.svg

# Render with options
d2 --theme 200 --layout elk --sketch diagram.d2 output.svg

# Render PNG
d2 diagram.d2 output.png

# Watch mode (live reload)
d2 --watch diagram.d2 output.svg

# List available themes
d2 themes
```
