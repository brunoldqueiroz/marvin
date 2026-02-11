# AI/ML Rules

## Prompt Engineering
- Start with the simplest prompt that could work
- Add complexity only when evaluation shows it's needed
- Always test prompts against edge cases (empty input, adversarial, long context)
- Version control all prompts — treat them as code
- Use structured output (JSON, tool_use) for machine-consumed results
- Set temperature=0 for deterministic outputs, >0 for creative tasks
- Include few-shot examples when the task involves pattern matching

## Model Development
- Define success metrics BEFORE training — no moving goalposts
- Always have a baseline to compare against (even a simple one)
- Log all experiments: parameters, metrics, artifacts, git commit hash
- Evaluate on held-out test sets — never on training data
- Prefer smaller models that meet requirements over larger ones
- Use cross-validation for small datasets
- Check for data leakage between train/test splits
- Pin random seeds for reproducibility

## Training Best Practices
- Start with a small subset to validate the pipeline works end-to-end
- Monitor training loss AND validation loss — detect overfitting early
- Use learning rate schedulers (cosine, linear warmup)
- Save checkpoints periodically, not just the final model
- Log training curves to experiment tracker
- Set reasonable timeouts — don't burn GPU hours on diverged runs

## RAG Systems
- Chunk size matters — experiment with 256-1024 tokens
- Overlap chunks by 10-20% to avoid splitting context
- Embed with the same model used for query encoding
- Evaluate retrieval quality (recall@k) separately from generation quality
- Always include source attribution in generated responses
- Re-rank retrieved results before passing to the generator
- Monitor retrieval latency and cache frequent queries

## LLM Applications
- Use Haiku for simple tasks, Sonnet for complex, Opus for reasoning-heavy
- Cache prompts when possible (prompt caching saves cost + latency)
- Implement retry with exponential backoff for API calls
- Set max_tokens to a reasonable limit (don't let it ramble)
- Use streaming for user-facing responses
- Log all LLM interactions for debugging and evaluation
- Implement fallback strategies (retry → simpler model → graceful error)

## Evaluation
- Use multiple metrics — a single number hides important tradeoffs
- Human evaluation for subjective tasks (summarization, creative writing)
- LLM-as-Judge for scalable evaluation with reference answers
- Regression test: track metrics across versions to catch degradation
- Benchmark against published baselines when possible

## Data Handling
- Version your datasets (DVC, git-lfs, or S3 versioning)
- Document data sources, collection date, preprocessing steps
- Check for bias in training data (class imbalance, demographic skew)
- Validate data schema before training (catch issues early)
- Keep raw data immutable — preprocessing produces new artifacts

## Anti-patterns (Avoid)
- Training without a baseline comparison
- Evaluating on training data ("100% accuracy!")
- Magic numbers in code (use config files or CLI args)
- Ignoring confidence/uncertainty in predictions
- Deploying without monitoring (model drift is real)
- Over-optimizing for benchmarks at the expense of real-world performance
- Using the largest model "just because" — cost and latency matter
