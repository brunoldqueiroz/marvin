# Project Context

This is an **AI/ML** project.

## Tech Stack
- **Language:** Python
- **Framework:** [PyTorch / TensorFlow / Hugging Face / scikit-learn — detect or ask]
- **Experiment Tracking:** [MLflow / Weights & Biases / TensorBoard — detect or ask]
- **Data:** [Pandas / Polars / DuckDB — detect or ask]
- **Deployment:** [FastAPI / Gradio / Docker / SageMaker — detect or ask]

## Architecture
```
Data → Features → Training → Evaluation → Deployment → Monitoring
```
- **Data:** Raw datasets, preprocessing pipelines
- **Features:** Feature engineering, embeddings, vectorization
- **Training:** Model training, hyperparameter tuning, experiment tracking
- **Evaluation:** Metrics, benchmarks, A/B testing
- **Deployment:** Model serving, API endpoints, batch inference

## Conventions
- Experiments tracked with clear names and metrics
- All hyperparameters configurable (no magic numbers in code)
- Evaluation on held-out test sets only (never training data)
- Reproducible: random seeds, pinned dependencies, versioned data
- Prompts version-controlled alongside code

## Project-Specific Agents
@.claude/registry/agents.md

## Project-Specific Skills
@.claude/registry/skills.md

## Domain Rules
@.claude/rules/ai-ml.md
