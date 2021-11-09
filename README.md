# Activerecord::Transactionable

Provides a method, `transaction_wrapper` at the class and instance levels that can be used instead of `ActiveRecord#transaction`.  Enables you to do transactions properly, with custom rescues and retry, including with or without locking.

| Project                    |  Activerecord::Transactionable |
|--------------------------- |--------------------------- |
| name, license, docs        |  [`activerecord-transactionable`][rubygems] [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)][license-ref] [![RubyDoc.info](https://img.shields.io/badge/documentation-rubydoc-brightgreen.svg?style=flat)][documentation] |
| version & downloads        |  [![Version](https://img.shields.io/gem/v/activerecord-transactionable.svg)][rubygems] [![Total Downloads](https://img.shields.io/gem/dt/activerecord-transactionable.svg)][rubygems] [![Downloads Today](https://img.shields.io/gem/rd/activerecord-transactionable.svg)][rubygems] [![Homepage](https://img.shields.io/badge/source-github-brightgreen.svg?style=flat)][source] |
| dependencies & linting     |  [![Depfu](https://badges.depfu.com/badges/d570491bac0ad3b0b65deb3c82028327/count.svg)][depfu] [![lint status](https://github.com/pboling/activerecord-transactionable/actions/workflows/style.yml/badge.svg)][actions] |
| unit tests                 |  [![supported rubies](https://github.com/pboling/activerecord-transactionable/actions/workflows/supported.yml/badge.svg)][actions] [![unsupported status](https://github.com/pboling/activerecord-transactionable/actions/workflows/unsupported.yml/badge.svg)][actions] |
| coverage & maintainability |  [![Test Coverage](https://api.codeclimate.com/v1/badges/41fa99881cfe6d45e7e5/test_coverage)][climate_coverage] [![codecov](https://codecov.io/gh/pboling/activerecord-transactionable/branch/master/graph/badge.svg?token=4ZNAWNxrf9)][codecov_coverage] [![Maintainability](https://api.codeclimate.com/v1/badges/41fa99881cfe6d45e7e5/maintainability)][climate_maintainability] [![Maintenance Policy](https://img.shields.io/badge/maintenance-policy-brightgreen.svg?style=flat)][maintenancee_policy] |
| resources                  |  [![Discussion](https://img.shields.io/badge/discussions-github-brightgreen.svg?style=flat)][gh_discussions] [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github) [![Join the chat at https://gitter.im/pboling/activerecord-transactionable](https://badges.gitter.im/Join%20Chat.svg)][chat] [![Blog](https://img.shields.io/badge/blog-railsbling-brightgreen.svg?style=flat)][blogpage] |
| Spread ~♡ⓛⓞⓥⓔ♡~         |  [![Open Source Helpers](https://www.codetriage.com/pboling/activerecord-transactionable/badges/users.svg)][code_triage] [![Liberapay Patrons](https://img.shields.io/liberapay/patrons/pboling.svg?logo=liberapay)][liberapay_donate] [![Sponsor Me](https://img.shields.io/badge/sponsor-pboling.svg?style=social&logo=github)][gh_sponsors] [🌏][aboutme] [👼][angelme] [💻][coderme] [🌹][politicme] [![Tweet @ Peter][followme-img]][tweetme] |

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

## Compatibility

Targeted ruby compatibility is non-EOL versions of Ruby, currently 2.6, 2.7, and
3.0. Ruby is limited to 2.1+ in the gemspec, and when it changes there will be a major release.
The `master` branch currently targets 2.0.x releases.

| Ruby OAuth Version   | Maintenance Branch | Officially Supported Rubies                 | Unofficially Supported Rubies |
|--------------------- | ------------------ | ------------------------------------------- | ----------------------------- |
| 3.0.x                | N/A                | 2.7, 3.0, 3.1                               | 2.6                           |
| 2.0.x                | `master`           | 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.0      |                               |

NOTE: 2.0.5 is anticipated as last release of the 2.x series.

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

## More Information

* RubyDoc Documentation: [![RubyDoc.info](https://img.shields.io/badge/documentation-rubydoc-brightgreen.svg?style=flat)][documentation]
* GitHub Discussions: [![Discussion](https://img.shields.io/badge/discussions-github-brightgreen.svg?style=flat)][gh_discussions]
* Live Chat on Gitter: [![Join the chat at https://gitter.im/pboling/activerecord-transactionable](https://badges.gitter.im/Join%20Chat.svg)][chat]
* Maintainer's Blog: [![Blog](https://img.shields.io/badge/blog-railsbling-brightgreen.svg?style=flat)][blogpage]

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

See [CONTRIBUTING.md][contributing]

## Code of Conduct

Everyone interacting with this project's code, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/pboling/activerecord-transactionable/blob/master/CODE_OF_CONDUCT.md).

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

* Copyright (c) 2016 - 2018, 2021 [Peter H. Boling][peterboling] of [Rails Bling][railsbling]

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

[license]: LICENSE
[semver]: http://semver.org/
[pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[railsbling]: http://www.railsbling.com
[peterboling]: http://www.peterboling.com
[documentation]: http://rdoc.info/github/pboling/activerecord-transactionable/frames
[homepage]: https://github.com/pboling/activerecord-transactionable/
[blogpage]: http://www.railsbling.com/tags/activerecord-transactionable/

[copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year

[license]: https://github.com/pboling/activerecord-transactionable/blob/master/LICENSE

[semver]: http://semver.org/

[pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint

[railsbling]: http://www.railsbling.com

[peterboling]: http://www.peterboling.com

[issues]: https://github.com/pboling/activerecord-transactionable/issues

[contributing]: https://github.com/pboling/activerecord-transactionable/blob/master/CONTRIBUTING.md

[comment]: <> (Following links are used by README, CONTRIBUTING)

[contributors]: https://github.com/pboling/activerecord-transactionable/graphs/contributors

[comment]: <> (Following links are used by README, CONTRIBUTING, Homepage)

[mailinglist]: http://groups.google.com/group/activerecord-transactionable-ruby

[source]: https://github.com/pboling/activerecord-transactionable/

[comment]: <> (Following links are used by Homepage)

[network]: https://github.com/pboling/activerecord-transactionable/network

[stargazers]: https://github.com/pboling/activerecord-transactionable/stargazers

[comment]: <> (Following links are used by README, Homepage)

[rubygems]: https://rubygems.org/gems/activerecord-transactionable

[depfu]: https://depfu.com/github/pboling/activerecord-transactionable?project_id=2653

[actions]: https://github.com/pboling/activerecord-transactionable/actions

[climate_coverage]: https://codeclimate.com/github/pboling/activerecord-transactionable/test_coverage

[gh_discussions]: https://github.com/pboling/activerecord-transactionable/discussions

[code_triage]: https://www.codetriage.com/pboling/activerecord-transactionable

[license-ref]: https://opensource.org/licenses/MIT

[codecov_coverage]: https://codecov.io/gh/pboling/activerecord-transactionable

[liberapay_donate]: https://liberapay.com/pboling/donate

[aboutme]: https://about.me/peter.boling

[angelme]: https://angel.co/peter-boling

[coderme]:http://coderwall.com/pboling

[politicme]: https://nationalprogressiveparty.org

[followme-img]: https://img.shields.io/twitter/follow/galtzo.svg?style=social&label=Follow

[tweetme]: http://twitter.com/galtzo

[documentation]: https://rubydoc.info/github/pboling/activerecord-transactionable

[climate_maintainability]: https://codeclimate.com/github/pboling/activerecord-transactionable/maintainability

[chat]: https://gitter.im/pboling/activerecord-transactionable?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge

[blogpage]: http://www.railsbling.com/tags/activerecord-transactionable/

[maintenancee_policy]: https://guides.rubyonrails.org/maintenance_policy.html#security-issues

[gh_sponsors]: https://github.com/sponsors/pboling
