# Activerecord::Transactionable

Provides a method, `transaction_wrapper` at the class and instance levels that can be used instead of `ActiveRecord#transaction`.

| Project                 |  FlagShihTzu      |
|------------------------ | ----------------- |
| gem name                |  activerecord-transactionable    |
| license                 |  MIT              |
| expert support          |  [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github) |
| download rank               |  [![Total Downloads](https://img.shields.io/gem/rt/activerecord-transactionable.svg)](https://rubygems.org/gems/activerecord-transactionable) |
| version                 |  [![Gem Version](https://badge.fury.io/rb/activerecord-transactionable.png)](http://badge.fury.io/rb/activerecord-transactionable) |
| dependencies            |  [![Dependency Status](https://gemnasium.com/pboling/activerecord-transactionable.png)](https://gemnasium.com/pboling/activerecord-transactionable) |
| code quality            |  [![Code Climate](https://codeclimate.com/github/pboling/activerecord-transactionable.png)](https://codeclimate.com/github/pboling/activerecord-transactionable) |
| inline documenation     |  [![Inline docs](http://inch-ci.org/github/pboling/activerecord-transactionable.png)](http://inch-ci.org/github/pboling/activerecord-transactionable) |
| continuous integration  |  [![Build Status](https://secure.travis-ci.org/pboling/activerecord-transactionable.png?branch=master)](https://travis-ci.org/pboling/activerecord-transactionable) |
| test coverage           |  [![Coverage Status](https://coveralls.io/repos/pboling/activerecord-transactionable/badge.png)](https://coveralls.io/r/pboling/activerecord-transactionable) |
| homepage                |  [https://github.com/pboling/activerecord-transactionable][homepage] |
| documentation           |  [http://rdoc.info/github/pboling/activerecord-transactionable/frames][documentation] |
| live chat               |  [![Join the chat at https://gitter.im/pboling/activerecord-transactionable](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/pboling/activerecord-transactionable?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) |
| Spread ~♡ⓛⓞⓥⓔ♡~                     |  [on Coderbits](https://coderbits.com/pboling), [on Coderwall](http://coderwall.com/pboling) |

Useful as an example of correct behavior for wrapping transactions.

NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
      see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activerecord-transactionable'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-transactionable

## Usage

```
class Car < ActiveRecord::Base
  include Activerecord::Transactionable # Note lowercase "r" in Activerecord (different namespace than rails' module)

  validates_presence_of :name
end
```

When creating, saving, deleting within the transaction make sure to use the bang methods (`!`) in order to ensure a rollback on failure.

When everything works:
```
car = Car.new(name: "Fiesta")
car.transaction_wrapper do
  car.save!
end
car.persisted? # => true
```

When something goes wrong:
```
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
```
car = Car.new(name: nil)
car.transaction_wrapper(lock: true) do # uses ActiveRecord's with_lock
  car.save!
end
car.persisted? # => false
car.errors.full_messages # => ["Name can't be blank"]
```

If you need to know if the transaction succeeded:
```
car = Car.new(name: nil)
result = car.transaction_wrapper(lock: true) do # uses ActiveRecord's with_lock
           car.save!
         end
result # => true, false or nil
```

Meanings of `transaction_wrapper` return values:

* **nil** - ActiveRecord::Rollback was raised, and then caught by the transaction, and not re-raised; the transaction failed.
* **false** - An error was raised which was handled by the transaction_wrapper; the transaction failed.
* **true** - The transaction was a success.

## Update Example

```
@client = Client.find(params[:id])
transaction_result =  @client.transaction_wrapper(lock: true) do
                        @client.assign_attributes(client_params)
                        @client.save!
                      end
if transaction_result
  render :show, locals: { client: @client }, status: :ok
else
  # Something prevented update
  render json: @client.errors, status: :unprocessable_entity
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/pboling/activerecord-transactionable.

[semver]: http://semver.org/
[pvc]: http://docs.rubygems.org/read/chapter/16#page74
[railsbling]: http://www.railsbling.com
[peterboling]: http://www.peterboling.com
[documentation]: http://rdoc.info/github/pboling/activerecord-transactionable/frames
[homepage]: https://github.com/pboling/activerecord-transactionable
