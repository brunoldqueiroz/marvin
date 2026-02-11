---
name: model
description: ML model training workflows, evaluation, and deployment
disable-model-invocation: true
argument-hint: "[train|evaluate|deploy|tune] [model or task description]"
---

# Model Skill

$ARGUMENTS

## Modes

### Train (new model or fine-tune)

1. **Define the task:**
   - What type? (classification, regression, generation, retrieval, ranking)
   - What metrics? (accuracy, F1, BLEU, ROUGE, MRR, custom)
   - What baseline? (random, majority class, simple model, previous version)

2. **Prepare data:**
   - Load and inspect the dataset
   - Check class distribution, missing values, data types
   - Split: train (80%) / validation (10%) / test (10%)
   - Feature engineering if needed
   - Save splits with versioning

3. **Configure the experiment:**
   - Create config file with all hyperparameters
   - Set experiment name: `{task}_{model}_{date}`
   - Initialize experiment tracker (MLflow / W&B / TensorBoard)
   - Pin random seed

4. **Train:**
   - Start with small subset to validate pipeline
   - Monitor training AND validation loss
   - Log metrics at each epoch/step
   - Save checkpoints periodically
   - Early stopping on validation metric

5. **Evaluate:**
   - Run on held-out test set (NEVER on training data)
   - Report multiple metrics
   - Compare against baseline
   - Generate confusion matrix / error analysis
   - Log all results to experiment tracker

Delegate to the **ai-ml** agent for complex training pipelines.

### Evaluate (existing model)

1. **Load model and test data**
2. **Run inference on test set**
3. **Compute metrics:**
   - Primary metric (the one you optimize for)
   - Secondary metrics (for understanding tradeoffs)
   - Per-class / per-category breakdown
4. **Error analysis:**
   - What does the model get wrong?
   - Are there patterns in the errors?
   - Sample and analyze worst predictions
5. **Report:**
   - Metrics table (compare with baseline and previous versions)
   - Confusion matrix or error distribution
   - Recommendations (more data? different model? better features?)

### Deploy (model to production)

1. **Validate the model:**
   - Confirm evaluation metrics meet threshold
   - Test with sample inputs
   - Check model size and inference latency
2. **Package:**
   - Export model in serving format (ONNX, TorchScript, SavedModel)
   - Create inference script / API endpoint
   - Pin all dependencies
3. **Serve:**
   - FastAPI / Gradio for APIs
   - Batch script for offline inference
   - Docker container for deployment
4. **Monitor:**
   - Log predictions and latency
   - Set up drift detection
   - Create alerting for anomalies

### Tune (hyperparameter optimization)

1. **Define search space** — which parameters, what ranges
2. **Choose strategy** — grid search, random search, Bayesian (Optuna)
3. **Run sweep** — track all trials in experiment tracker
4. **Analyze results** — parameter importance, interactions
5. **Select best** — retrain with best params on full training set
