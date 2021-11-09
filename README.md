# Activerecord::Transactionable

Provides a method, `transaction_wrapper` at the class and instance levels that can be used instead of `ActiveRecord#transaction`.  Enables you to do transactions properly, with custom rescues and retry, including with or without locking.

| Project                 | Activerecord::Transactionable    |
|------------------------ | ----------------- |
| gem name                |  activerecord-transactionable    |
| license                 |  [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT) |
| download rank               |  [![Total Downloads](https://img.shields.io/gem/rt/activerecord-transactionable.svg)](https://rubygems.org/gems/activerecord-transactionable) [![Daily Downloads](https://img.shields.io/gem/rd/activerecord-transactionable.svg)](https://rubygems.org/gems/activerecord-transactionable) |
| version                 |  [![Version](https://img.shields.io/gem/v/activerecord-transactionable.svg)](https://rubygems.org/gems/activerecord-transactionable) |
| dependencies            |  [![Depfu](https://badges.depfu.com/badges/96a4d507f1a61a9368655f60fa3cb70f/count.svg)](https://depfu.com/github/pboling/activerecord-transactionable?project_id=2653) |
| continuous integration  |  [![Build](https://img.shields.io/travis/pboling/activerecord-transactionable.svg)](https://travis-ci.org/pboling/activerecord-transactionable) |
| test coverage           |  [![Test Coverage](https://api.codeclimate.com/v1/badges/41fa99881cfe6d45e7e5/test_coverage)](https://codeclimate.com/github/pboling/activerecord-transactionable/test_coverage) [![Coverage Status](https://coveralls.io/repos/github/pboling/activerecord-transactionable/badge.svg?branch=master)](https://coveralls.io/github/pboling/activerecord-transactionable?branch=master) |
| code quality            |  [![Maintainability](https://api.codeclimate.com/v1/badges/41fa99881cfe6d45e7e5/maintainability)](https://codeclimate.com/github/pboling/activerecord-transactionable/maintainability) |
| code triage             |  [![Open Source Helpers](https://www.codetriage.com/pboling/activerecord-transactionable/badges/users.svg)](https://www.codetriage.com/pboling/activerecord-transactionable) |
| inline documenation     |  [![Inline docs](http://inch-ci.org/github/pboling/activerecord-transactionable.png)](http://inch-ci.org/github/pboling/activerecord-transactionable) |
| homepage                |  [on Github.com][homepage], [on Railsbling.com][blogpage] |
| documentation           |  [on RDoc.info][documentation] |
| live chat               |  [![Join the chat at https://gitter.im/pboling/activerecord-transactionable](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/pboling/activerecord-transactionable?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) |
| expert support          |  [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github) |
| Spread ~♡ⓛⓞⓥⓔ♡~      |  [🌏](https://about.me/peter.boling), [👼](https://angel.co/peter-boling), [:shipit:](http://coderwall.com/pboling), [![Tweet Peter](https://img.shields.io/twitter/follow/galtzo.svg?style=social&label=Follow)](http://twitter.com/galtzo), [🌹](https://nationalprogressiveparty.org) |

Useful as an example of correct behavior for wrapping transactions.

NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
      see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html

## Upgrading to Version 2

In version 1 the `transaction_wrapper` returned `true` or `false`.  In version 2 it returns an instance of `Activerecord::Transactionable::Result`, which has a `value`, and three methods:
```ruby
args = {}
result = transaction_wrapper(**args) do
  something
end
result.fail?
result.success?
result.to_h # => a hash with diagnostic information, particularly useful when things go wrong
```
Where you used to have:
```ruby
if result
  # ...
end
```
You must update to:
```ruby
if result.success?
  # ...
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem "activerecord-transactionable"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-transactionable

## Usage

```ruby
class Car < ActiveRecord::Base
  include Activerecord::Transactionable # Note lowercase "r" in Activerecord (different namespace than rails' module)

  validates_presence_of :name
end
```

When creating, saving, deleting within the transaction make sure to use the bang methods (`!`) in order to ensure a rollback on failure.

When everything works:

```ruby
car = Car.new(name: "Fiesta")
car.transaction_wrapper do
  car.save!
end
car.persisted? # => true
```

When something goes wrong:

```ruby
car = Car.new(name: nil)
car.transaction_wrapper do
  car.save!
end
car.persisted? # => false
car.errors.full_messages # => ["Name can't be blank"]
```

These examples are too simple to be useful with transactions, but if you are working with multiple records then it will make sense.

Also see the specs.

If you need to lock the car as well as have a transaction (note: will reload the `car`):

```ruby
car = Car.new(name: nil)
car.transaction_wrapper(lock: true) do # uses ActiveRecord's with_lock
  car.save!
end
car.persisted? # => false
car.errors.full_messages # => ["Name can't be blank"]
```

If you need to know if the transaction succeeded:

```ruby
car = Car.new(name: nil)
result = car.transaction_wrapper(lock: true) do # uses ActiveRecord's with_lock
           car.save!
end
result # => an instance of Activerecord::Transactionable::Result
result.success? # => true or false
```

## Update Example

```ruby
@client = Client.find(params[:id])
transaction_result = @client.transaction_wrapper(lock: true) do
                        @client.assign_attributes(client_params)
                        @client.save!
end
if transaction_result.success?
  render :show, locals: { client: @client }, status: :ok
else
  # Something prevented update, transaction_result.to_h will have all the available details
  render json: { record_errors: @client.errors, transaction_result: transaction_result.to_h }, status: :unprocessable_entity
end
```

## Find or create

NOTE: The `is_retry` is passed to the block by the gem, and indicates whether the block is running for the first time or the second, or nth, time.
The block will never be retried more than once.

```ruby
Car.transaction_wrapper(outside_retriable_errors: ActivRecord::RecordNotFound, outside_num_retry_attempts: 3) do |is_retry|
  # is_retry will be falsey on first attempt, thereafter will be the integer number of the attempt
  if is_retry
    Car.create!(vin: vin)
  else
    Car.find_by!(vin: vin)
  end
end
```

## Create or find

NOTE: The `is_retry` is passed to the block by the gem, and indicates whether the block is running for the first time or the second time.
The block will never be retried more than once.

```ruby
Car.transaction_wrapper(outside_retriable_errors: ActivRecord::RecordNotUnique) do |is_retry|
  # is_retry will be falsey on first attempt, thereafter will be the integer number of the attempt
  if is_retry
    Car.find_by!(vin: vin)
  else
    Car.create!(vin: vin)
  end
end
```

## Reporting to SAAS Error Tools (like Raygun, etc)

Hopefully there will be a better integration at some point, but for now, somewhere in your code do:

```ruby
module SendToRaygun
  def transaction_error_logger(**args)
    super
    if args[:error]
      begin
        Raygun.track_exception(args[:error])
        Rails.logger.debug("Sent Error to Raygun: #{args[:error].class}: #{args[:error].message}")
      rescue StandardError => e
        Rails.logger.error("Sending Error #{args[:error].class}: #{args[:error].message} to Raygun Failed with: #{e.class}: #{e.message}")
      end
    end
  end
end

Activerecord::Transactionable::ClassMethods.class_eval do
  prepend SendToRaygun
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pboling/activerecord-transactionable. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## Code of Conduct

Everyone interacting in the AnonymousActiveRecord project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/pboling/activerecord-transactionable/blob/master/CODE_OF_CONDUCT.md).

## Versioning

This library aims to adhere to [Semantic Versioning 2.0.0][semver].
Violations of this scheme should be reported as bugs. Specifically,
if a minor or patch version is released that breaks backward
compatibility, a new version should be immediately released that
restores compatibility. Breaking changes to the public API will
only be introduced with new major versions.

As a result of this policy, you can (and should) specify a
dependency on this gem using the [Pessimistic Version Constraint][pvc] with two digits of precision.

For example:

```ruby
spec.add_dependency "activerecord-transactionable", "~> 2.0"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pboling/activerecord-transactionable.

## License

* Copyright (c) 2016 - 2018 [Peter H. Boling][peterboling] of [Rails Bling][railsbling]

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[license]: LICENSE
[semver]: http://semver.org/
[pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[railsbling]: http://www.railsbling.com
[peterboling]: http://www.peterboling.com
[documentation]: http://rdoc.info/github/pboling/activerecord-transactionable/frames
[homepage]: https://github.com/pboling/activerecord-transactionable/
[blogpage]: http://www.railsbling.com/tags/activerecord-transactionable/
