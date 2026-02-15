# Job Continuations

## Overview

Job continuations allow you to break complex jobs into smaller, resumable steps. This feature was introduced to help organize long-running jobs and make them more resilient to interruptions.

## When to Use Job Continuations

Use job continuations when you have:
- Multi-step workflows that can be paused and resumed
- Jobs that need to update UI progressively
- Complex operations that benefit from intermediate checkpoints
- Long-running processes that could timeout without checkpointing

## Basic Continuation Usage

To make a job resumable, include the `ActiveJob::Continuable` module:

```ruby
class ComplexWorkflowJob < ApplicationJob
  include ActiveJob::Continuable
  
  def perform
    logger.info "Step 1: Processing data"
    # ... perform first step ...
    
    resume_later_with(:step_two)
  end
  
  def step_two
    logger.info "Step 2: Analyzing results"
    # ... perform second step ...
    
    resume_later_with(:step_three)
  end
  
  def step_three
    logger.info "Step 3: Finalizing"
    # ... perform final step ...
  end
end
```

## How It Works

1. **Initial Job Execution**: The `perform` method runs and processes the first step
2. **Resume Point**: Call `resume_later_with(:method_name)` to schedule the next step
3. **Next Step**: The specified method is invoked as a continuation
4. **Chaining**: Each step can call `resume_later_with` to chain to the next step

## Advanced Patterns

### Conditional Continuations

```ruby
class ProcessingJob < ApplicationJob
  include ActiveJob::Continuable
  
  def perform(data_id)
    @data = Data.find(data_id)
    validate_data
    
    if @data.valid?
      resume_later_with(:process_data)
    else
      resume_later_with(:log_errors)
    end
  end
  
  def process_data
    # ... process ...
    resume_later_with(:finalize)
  end
  
  def log_errors
    # ... log validation errors ...
  end
  
  def finalize
    # ... cleanup ...
  end
end
```

### Passing Data Between Steps

```ruby
class DataTransformationJob < ApplicationJob
  include ActiveJob::Continuable
  
  def perform(source_id)
    @source = Source.find(source_id)
    raw_data = fetch_data
    
    resume_later_with(:transform, raw_data)
  end
  
  def transform(raw_data)
    transformed = transform_data(raw_data)
    resume_later_with(:validate, transformed)
  end
  
  def validate(data)
    validated = validate_data(data)
    
    if validated.valid?
      resume_later_with(:save, validated)
    else
      handle_validation_error(validated)
    end
  end
  
  def save(data)
    # ... persist data ...
  end
end
```

### With Error Handling

```ruby
class RobustWorkflowJob < ApplicationJob
  include ActiveJob::Continuable
  discard_on StandardError
  
  def perform(job_id)
    @job = Job.find(job_id)
    
    begin
      initial_processing
      resume_later_with(:next_step)
    rescue => e
      log_error(e)
      rethrow
    end
  end
  
  def next_step
    # ... processing ...
  end
end
```

## Comparison: Continuations vs. Job Chaining

### Using Continuations
```ruby
class WorkflowJob < ApplicationJob
  include ActiveJob::Continuable
  
  def perform; ... ; resume_later_with(:step2) ; end
  def step2; ... ; resume_later_with(:step3) ; end
  def step3; ... ; end
end

WorkflowJob.perform_later(arg)
```

### Using Separate Jobs (Alternative)
```ruby
class Step1Job < ApplicationJob
  def perform(arg)
    ...
    Step2Job.perform_later(arg)
  end
end

class Step2Job < ApplicationJob
  def perform(arg)
    ...
    Step3Job.perform_later(arg)
  end
end

Step1Job.perform_later(arg)
```

**Continuations advantages:**
- Cleaner code organization
- Single job ID for tracking
- Shared instance variables across steps
- Built-in support for resumable workflows

## Best Practices

1. **Keep steps focused**: Each step should have a single responsibility
2. **Use explicit naming**: Use descriptive method names like `validate_data`, `process_results`
3. **Handle state carefully**: Document what state is expected at each step
4. **Add logging**: Log step transitions for debugging
5. **Consider timeout**: Very long continuation chains might hit timeouts
6. **Test each step**: Write unit tests for individual continuation methods

## Rails Version Support

Job continuations are available in Rails 8.0+. Check your Rails version:

```ruby
Rails::VERSION::MAJOR >= 8
```

For earlier Rails versions, use separate job classes and chain them via job callbacks or explicit calls.
