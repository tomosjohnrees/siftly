# Siftly

`siftly` is the core runtime. It does not ship opinionated spam rules. It gives you:

- a filter contract
- a registry
- pipeline configuration
- result objects
- aggregation and failure handling

Use this gem directly if you are writing your own filters. Add one or more plugin gems if you want ready-made heuristics.

## Installation

```ruby
gem "siftly"
```

## Usage

Load the core gem plus any plugin gems you want to use, configure the active filters once, then call `Siftly.check`.

```ruby
require "siftly"
require "siftly/content"
require "siftly/links"

Siftly.configure do |config|
  config.aggregator = :score
  config.threshold = 1.0
  config.failure_mode = :record

  config.use :keyword_pack
  config.use :shortener_link

  config.filter :keyword_pack do |filter|
    filter.keywords = ["seo agency", "buy backlinks", "guest post"]
    filter.weight = 0.4
  end
end

result = Siftly.check(
  value: "Our SEO agency can buy backlinks. Details: https://bit.ly/demo",
  attribute: :message,
  context: { source: "contact_form" }
)

result.spam?    # => true
result.score    # => 1.3
result.reasons  # => ["Matched 2 configured keyword terms", "Submission contains shortened URLs"]
result.matches.map(&:filter) # => [:keyword_pack, :shortener_link]
```

## Configuration Reference

`Siftly.configure` yields a `Siftly::Config` object. These are the supported global settings.

### `config.use(key)`

Enables a filter for all future `Siftly.check` calls unless that call passes an explicit `filters:` list.

Accepted values:

- a symbol such as `:keyword_pack`
- a string such as `"keyword_pack"`

Behavior:

- keys are normalized to symbols
- duplicate calls are ignored
- order is preserved, and filters run in that order

### `config.filter(key) { |filter| ... }`

Creates or updates a `Siftly::FilterConfig` for the named filter.

Accepted values for `key`:

- a symbol
- a string

Inside the block, `filter` is a mutable `Siftly::FilterConfig`.

You can set arbitrary keys on it:

```ruby
config.filter :keyword_pack do |filter|
  filter.keywords = ["seo agency", "buy backlinks"]
  filter.weight = 0.4
  filter.min_hits = 2
end
```

Important detail:

- the core gem does not validate per-filter settings
- each filter decides which keys it reads
- unknown settings are simply stored and ignored unless the filter uses them

### `config.aggregator`

Controls how filter results are combined into the final spam decision.

Default:

- `:score`

Accepted values:

- `:score`
- `:weighted` as an alias for `:score`
- `:any`
- any object responding to `call(filter_results:, threshold:, context:)`

Built-in behavior:

- `:score` and `:weighted` sum all filter scores and mark spam when `score >= threshold`
- `:any` marks spam when any filter matches

Custom aggregator contract:

```ruby
class MyAggregator
  def call(filter_results:, threshold:, context:)
    { spam: true_or_false, score: numeric_score }
  end
end
```

If `aggregator` is set to anything else, Siftly raises `Siftly::InvalidAggregatorError`.

### `config.threshold`

Controls the spam cutoff used by score-based aggregation.

Default:

- `1.0`

Accepted values:

- any numeric value that can be converted with `to_f`

Notes:

- it matters for `:score`, `:weighted`, and most custom aggregators
- it does not affect the built-in `:any` aggregator

### `config.failure_mode`

Controls what happens when a filter raises an exception.

Default:

- `:record`

Accepted values:

- `:record`
- `:open`
- `:closed`
- `:raise`

Behavior:

- `:record` records the filter error, continues the pipeline, and treats that filter as a non-match with score `0.0`
- `:open` currently behaves the same as `:record`
- `:closed` records the filter error, forces that filter to match, and gives it a score equal to the pipeline threshold
- `:raise` re-raises the original exception immediately

If `failure_mode` is set to anything else, Siftly raises `Siftly::ConfigurationError`.

### `config.instrumenter`

Receives instrumentation events from the pipeline.

Default:

- `nil`

Accepted values:

- `nil`
- any object responding to `instrument(event, payload = {})`

Events emitted by the pipeline:

- `siftly.filter.started`
- `siftly.filter.finished`
- `siftly.pipeline.completed`

`payload` is a hash and varies by event. For example, `siftly.filter.finished` includes fields such as `filter`, `attribute`, `matched`, `score`, `duration_ms`, and `error` when applicable.

### `config.enabled_filters`

Read-only array of enabled filter keys.

Default:

- `[]`

Values returned:

- an array of symbols in execution order

### `config.filter_config_for(key)`

Returns a copy of the current `Siftly::FilterConfig` for that filter.

Accepted values for `key`:

- a symbol
- a string

Return behavior:

- returns an existing config copy if one has been set
- returns an empty config object for that key if one has not

### `config.filter_configs`

Returns a hash of all configured filter configs.

Return shape:

```ruby
{
  keyword_pack: #<Siftly::FilterConfig ...>,
  shortener_link: #<Siftly::FilterConfig ...>
}
```

### `config.dup`

Returns a deep copy of the configuration.

This duplicates:

- enabled filters
- filter configs
- aggregator
- threshold
- failure mode
- instrumenter reference

## `Siftly.check` Reference

`Siftly.check` accepts the following keyword arguments.

### `value:`

Required.

Accepted values:

- any object

Behavior:

- Siftly passes it to each filter as-is
- most filters call `to_s`, but that is filter-specific

### `attribute:`

Optional.

Accepted values:

- `nil`
- typically a symbol such as `:email` or `:message`
- strings also work if the filter handles them

Default:

- `nil`

### `record:`

Optional.

Accepted values:

- `nil`
- any object, typically a model or form object

Default:

- `nil`

### `context:`

Optional.

Accepted values:

- a hash

Default:

- `{}`

Use this for request metadata and external signals such as:

- IP address
- user agent
- form timing
- honeypot values
- precomputed fingerprints

### `filters:`

Optional.

Accepted values:

- `nil`
- an array of symbols or strings

Default:

- `nil`, which means "use `config.enabled_filters`"

Behavior:

- keys are normalized to symbols
- passing `filters:` replaces the globally enabled filter list for that call

### `filter_overrides:`

Optional.

Accepted values:

- a hash keyed by filter symbol or string

Default:

- `{}`

Example:

```ruby
Siftly.check(
  value: "special phrase",
  filters: [:keyword_pack],
  filter_overrides: {
    keyword_pack: {
      keywords: ["special phrase"],
      weight: 0.9
    }
  }
)
```

Behavior:

- overrides are merged into the configured `FilterConfig` for that call only
- string and symbol keys are both supported for filter names

### `aggregator:`

Optional per-call override for `config.aggregator`.

Accepted values:

- `:score`
- `:weighted`
- `:any`
- a custom aggregator object

Default:

- the configured global aggregator

### `threshold:`

Optional per-call override for `config.threshold`.

Accepted values:

- any numeric value convertible with `to_f`

Default:

- the configured global threshold

### `failure_mode:`

Optional per-call override for `config.failure_mode`.

Accepted values:

- `:record`
- `:open`
- `:closed`
- `:raise`

Default:

- the configured global failure mode

### `instrumenter:`

Optional per-call override for `config.instrumenter`.

Accepted values:

- `nil`
- any object responding to `instrument(event, payload = {})`

Default:

- the configured global instrumenter

## `Siftly::FilterConfig` Reference

`Siftly::FilterConfig` stores per-filter settings.

Supported methods:

- `key` returns the filter key as a symbol
- `config[:setting_name]` reads a stored setting
- `config.fetch(:setting_name, default)` reads a stored setting with fallback
- dynamic writers such as `config.weight = 0.7`
- dynamic readers such as `config.weight`
- `to_h` returns a copy of the settings hash
- `merge(overrides)` returns a new `FilterConfig` with merged overrides

Accepted setting values:

- any Ruby object

The core gem does not impose a schema here. Plugin filters define their own supported keys.

## Writing a filter

Subclass `Siftly::Filter`, call `register_as`, and return `result(...)` from `#call`.

```ruby
require "siftly"

class BlocklistFilter < Siftly::Filter
  register_as :blocklist

  def call(value:, attribute: nil, record: nil, context: {})
    blocked = Array(config.fetch(:blocked_terms, []))
    matched_terms = blocked.select { |term| value.to_s.downcase.include?(term.downcase) }

    result(
      matched: matched_terms.any?,
      score: matched_terms.any? ? config.fetch(:weight, 1.0).to_f : 0.0,
      reason: matched_terms.any? ? "Matched blocked terms" : nil,
      metadata: { matched_terms: matched_terms, attribute: attribute, context_keys: context.keys }
    )
  end
end

Siftly::Registry.register(BlocklistFilter)
```

## Results

`Siftly.check` returns `Siftly::Result`.

- `spam?` tells you whether the pipeline classified the input as spam
- `score` is the summed score from all filter results
- `matches` returns only the matched `Siftly::FilterResult` objects
- `errors` returns only filters that failed
- `reasons` is a flat list of non-nil match reasons
- `filter_results` contains every filter result, matched or not

Each `Siftly::FilterResult` exposes:

- `filter`
- `matched?`
- `score`
- `reason`
- `metadata`
- `error?`

Additional result fields:

- `Siftly::Result#attribute`
- `Siftly::Result#value_preview`
- `Siftly::Result#threshold`
- `Siftly::Result#aggregator`

Additional filter result fields:

- `Siftly::FilterResult#error`
- `Siftly::FilterResult#duration_ms`

## Utility Methods

### `Siftly.config`

Returns the current global `Siftly::Config` instance.

### `Siftly.reset_configuration!`

Resets the global configuration back to defaults:

- no enabled filters
- no filter configs
- `aggregator = :score`
- `threshold = 1.0`
- `failure_mode = :record`
- `instrumenter = nil`

## Plugin loading

Plugin gems register their filters when required. If a check fails with an unknown filter error, you either forgot to add the plugin gem or forgot to require it.
