# Activerecord::Transactionable

<div id="badges">

[![CI Build][🚎dl-cwfi]][🚎dl-cwf]
[![Test Coverage][🔑cc-covi]][🔑cc-cov]
[![Maintainability][🔑cc-mnti]][🔑cc-mnt]
[![Depfu][🔑depfui]][🔑depfu]

-----

[![Liberapay Patrons][⛳liberapay-img]][⛳liberapay]
[![Sponsor Me on Github][🖇sponsor-img]][🖇sponsor]
<span class="badge-buymeacoffee">
<a href="https://ko-fi.com/O5O86SNP4" target='_blank' title="Donate to my FLOSS or refugee efforts at ko-fi.com"><img src="https://img.shields.io/badge/buy%20me%20coffee-donate-yellow.svg" alt="Buy me coffee donation button" /></a>
</span>
<span class="badge-patreon">
<a href="https://patreon.com/galtzo" title="Donate to my FLOSS or refugee efforts using Patreon"><img src="https://img.shields.io/badge/patreon-donate-yellow.svg" alt="Patreon donate button" /></a>
</span>

</div>

[🚎dl-cwf]: https://github.com/pboling/activerecord-transactionable/actions/workflows/current.yml
[🚎dl-cwfi]: https://github.com/pboling/activerecord-transactionable/actions/workflows/current.yml/badge.svg

[⛳liberapay-img]: https://img.shields.io/liberapay/patrons/pboling.svg?logo=liberapay
[⛳liberapay]: https://liberapay.com/pboling/donate
[🖇sponsor-img]: https://img.shields.io/badge/Sponsor_Me!-pboling.svg?style=social&logo=github
[🖇sponsor]: https://github.com/sponsors/pboling

Provides a method, `transaction_wrapper` at the class and instance levels that can be used instead of `ActiveRecord#transaction`.  Enables you to do transactions properly, with custom rescues and retry, including with or without locking.

| Project         | Activerecord::Transactionable                                                                                                                                                                                                                                                                                                     |
|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| install         | `bundle add activerecord-transactionable`                                                                                                                                                                                                                                                                                         |
| compatibility   | Ruby >= 2.5                                                                                                                                                                                                                                                                                                                       |
| license         | [![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)                                                                                                                                                                                                                        |
| download rank   | [![Downloads Today](https://img.shields.io/gem/rd/activerecord-transactionable.svg)](https://github.com/pboling/activerecord-transactionable)                                                                                                                                                                                     |
| version         | [![Version](https://img.shields.io/gem/v/activerecord-transactionable.svg)](https://rubygems.org/gems/activerecord-transactionable)                                                                                                                                                                                               |
| code triage     | [![Open Source Helpers](https://www.codetriage.com/pboling/activerecord-transactionable/badges/users.svg)](https://www.codetriage.com/pboling/activerecord-transactionable)                                                                                                                                                       |
| documentation   | [on RDoc.info][documentation]                                                                                                                                                                                                                                                                                                     |
| live chat       | [![Join the chat at https://gitter.im/pboling/activerecord-transactionable](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/pboling/activerecord-transactionable?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)                                                                          |
| expert support  | [![Get help on Codementor](https://cdn.codementor.io/badges/get_help_github.svg)](https://www.codementor.io/peterboling?utm_source=github&utm_medium=button&utm_term=peterboling&utm_campaign=github)                                                                                                                             |
| Spread ~♡ⓛⓞⓥⓔ♡~ | [🌏](https://about.me/peter.boling), [👼](https://angel.co/peter-boling), [![Liberapay Patrons][⛳liberapay-img]][⛳liberapay] [![Follow Me on LinkedIn][🖇linkedin-img]][🖇linkedin] [![Find Me on WellFound:][✌️wellfound-img]][✌️wellfound] [![My Blog][🚎blog-img]][🚎blog] [![Follow Me on Twitter][🐦twitter-img]][🐦twitter] |

[documentation]: https://rubydoc.info/github/pboling/activerecord-transactionable
[🖇linkedin]: http://www.linkedin.com/in/peterboling
[🖇linkedin-img]: https://img.shields.io/badge/PeterBoling-blue?style=plastic&logo=linkedin
[✌️wellfound]: https://angel.co/u/peter-boling
[✌️wellfound-img]: https://img.shields.io/badge/peter--boling-orange?style=plastic&logo=angellist
[🐦twitter]: http://twitter.com/intent/user?screen_name=galtzo
[🐦twitter-img]: https://img.shields.io/twitter/follow/galtzo.svg?style=social&label=Follow%20@galtzo
[🚎blog]: http://www.railsbling.com/tags/oauth2/
[🚎blog-img]: https://img.shields.io/badge/blog-railsbling-brightgreen.svg?style=flat
[my🧪lab]: https://gitlab.com/pboling
[my🧊berg]: https://codeberg.org/pboling
[my🛖hut]: https://sr.ht/~galtzo/

Useful as an example of correct behavior for wrapping transactions.

NOTE: Rails' transactions are per-database connection, not per-model, nor per-instance,
      see: http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html

## Upgrading to Version 2

In version 1 the `transaction_wrapper` returned `true` or `false`.  In version 2 it returns an instance of `Activerecord::Transactionable::Result`, which has a `value`, and three methods:

```ruby

args = {}
result = transaction_wrapper(**args) do
  # some code that might fail here
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

Targeted ruby compatibility is non-EOL versions of Ruby, currently 2.6, 2.7, 3.0, 3.1, 3.2, 3.3.
Ruby is limited to 2.5+ in the gemspec, and when it changes there will be a major release.
The `master` branch currently targets 3.0.x releases.

| Ruby OAuth Version | Maintenance Branch | Officially Supported Rubies            | Unofficially Supported Rubies |
|--------------------|--------------------|----------------------------------------|-------------------------------|
| 3.0.x              | `master`           | 2.6, 2.7, 3.0, 3.1, 3.2, 3.3           | 2.5                           |
| 2.0.x              | `v2-maintenance`   | 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 3.0 |                               |

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
  render :show, locals: {client: @client}, status: :ok
else
  # Something prevented update, transaction_result.to_h will have all the available details
  render json: {record_errors: @client.errors, transaction_result: transaction_result.to_h}, status: :unprocessable_entity
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

## 🪇 Code of Conduct

Everyone interacting in this project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the [code of conduct][🪇conduct].

[🪇conduct]: CODE_OF_CONDUCT.md

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## 🛞 DVCS

This project does not trust any one version control system,
so it abides the principles of ["Distributed Version Control Systems"][💎d-in-dvcs]

Find this project on:

| Any            | Of               | These          | DVCS           |
|----------------|------------------|----------------|----------------|
| [🐙hub][🐙hub] | [🧊berg][🧊berg] | [🛖hut][🛖hut] | [🧪lab][🧪lab] |

[comment]: <> ( DVCS LINKS )

[💎d-in-dvcs]: https://railsbling.com/posts/dvcs/put_the_d_in_dvcs/

[🧊berg]: https://codeberg.org/pboling/activerecord-transactionable
[🐙hub]: https://gitlab.com/pboling/activerecord-transactionable
[🛖hut]: https://sr.ht/~galtzo/pboling/activerecord-transactionable
[🧪lab]: https://gitlab.com/pboling/activerecord-transactionable

## 🤝 Contributing

See [CONTRIBUTING.md][🤝contributing]

[🤝contributing]: CONTRIBUTING.md

## 🌈 Contributors

[![Contributors][🌈contrib-rocks-img]][🐙hub-contrib]

Contributor tiles (GitHub only) made with [contributors-img][🌈contrib-rocks].

Learn more about, or become one of, our 🎖 contributors on:

| Any                                 | Of                                    | These                               | DVCS                                |
|-------------------------------------|---------------------------------------|-------------------------------------|-------------------------------------|
| [🐙hub contributors][🐙hub-contrib] | [🧊berg contributors][🧊berg-contrib] | [🛖hut contributors][🛖hut-contrib] | [🧪lab contributors][🧪lab-contrib] |

[comment]: <> ( DVCS CONTRIB LINKS )

[🌈contrib-rocks]: https://contrib.rocks
[🌈contrib-rocks-img]: https://contrib.rocks/image?repo=pboling/activerecord-transactionable

[🧊berg-contrib]: https://codeberg.org/pboling/activerecord-transactionable/activity
[🐙hub-contrib]: https://github.com/pboling/activerecord-transactionable/graphs/contributors
[🛖hut-contrib]: https://git.sr.ht/~galtzo/activerecord-transactionable/log/
[🧪lab-contrib]: https://gitlab.com/pboling/activerecord-transactionable/-/graphs/main?ref_type=heads

## 📌 Versioning

This Library adheres to [Semantic Versioning 2.0.0][📌semver].
Violations of this scheme should be reported as bugs.
Specifically, if a minor or patch version is released that breaks backward compatibility,
a new version should be immediately released that restores compatibility.
Breaking changes to the public API will only be introduced with new major versions.

To get a better understanding of how SemVer is intended to work over a project's lifetime,
read this article from the creator of SemVer:

- ["Major Version Numbers are Not Sacred"][📌major-versions-not-sacred]

As a result of this policy, you can (and should) specify a dependency on these libraries using
the [Pessimistic Version Constraint][📌pvc] with two digits of precision.

For example:

```ruby
spec.add_dependency("activerecord-transactionable", "~> 3.0")
```

[comment]: <> ( 📌 VERSIONING LINKS )

[📌pvc]: http://guides.rubygems.org/patterns/#pessimistic-version-constraint
[📌semver]: http://semver.org/
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html

## Contact

Author and maintainer is Peter Boling ([@pboling][gh_sponsors]).

Feedback and questions are welcome on the [GitHub Discussions][gh_discussions] board.

For security-related issues see [SECURITY][security].

[security]: https://github.com/pboling/activerecord-transactionable/blob/master/SECURITY.md
[gh_discussions]: https://github.com/pboling/activerecord-transactionable/discussions
[gh_sponsors]: https://github.com/sponsors/pboling

## 📄 License

The gem is available as open source under the terms of
the [MIT License][📄license] [![License: MIT][📄license-img]][📄license-ref].
See [LICENSE.txt][📄license] for the official [Copyright Notice][📄copyright-notice-explainer].

[comment]: <> ( 📄 LEGAL LINKS )

[📄copyright-notice-explainer]: https://opensource.stackexchange.com/questions/5778/why-do-licenses-such-as-the-mit-license-specify-a-single-year
[📄license]: LICENSE.txt
[📄license-ref]: https://opensource.org/licenses/MIT
[📄license-img]: https://img.shields.io/badge/License-MIT-green.svg

### © Copyright

* Copyright (c) 2016-2018, 2021-2022, 2024 [Peter H. Boling][💁🏼‍♂️peterboling] of [Rails Bling][💁🏼‍♂️railsbling]

[comment]: <> ( 🔑 KEYED LINKS )

[🔑cc-mnt]: https://codeclimate.com/github/pboling/activerecord-transactionable/maintainability
[🔑cc-mnti]: https://api.codeclimate.com/v1/badges/<key>/maintainability
[🔑cc-cov]: https://codeclimate.com/github/pboling/activerecord-transactionable/test_coverage
[🔑cc-covi]: "https://api.codeclimate.com/v1/badges/<key>/test_coverage"
[🔑depfu]: "https://depfu.com/github/pboling/activerecord-transactionable?project_id=2653"
[🔑depfui]: "https://badges.depfu.com/badges/d570491bac0ad3b0b65deb3c82028327/count.svg"

[comment]: <> ( 💁🏼‍♂️ PERSONAL LINKS )

[💁🏼‍♂️aboutme]: https://about.me/peter.boling
[💁🏼‍♂️angellist]: https://angel.co/peter-boling
[💁🏼‍♂️devto]: https://dev.to/galtzo
[💁🏼‍♂️followme]: https://img.shields.io/twitter/follow/galtzo.svg?style=social&label=Follow
[💁🏼‍♂️twitter]: http://twitter.com/galtzo
[💁🏼‍♂️peterboling]: http://www.peterboling.com
[💁🏼‍♂️railsbling]: http://www.railsbling.com

[comment]: <> ( 💼 PROJECT LINKS )

[💼blogpage]: http://www.railsbling.com/tags/activerecord-transactionable/
[💼documentation]: http://rdoc.info/github/activerecord-transactionable/meta/frames
[💼homepage]: https://github.com/pboling/activerecord-transactionable
