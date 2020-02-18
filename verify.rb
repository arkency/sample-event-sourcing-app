event_store = Rails.configuration.event_store
repository = AggregateRoot::Repository.new(event_store)

FailedExpectations = Class.new(StandardError)
def assert_all(actual, expected)
  match = actual == expected
  return if match
  raise FailedExpectations, <<-MSG
    Actual values: #{actual}
    do not match expected ones: #{expected}
  MSG
end

def register_participant(repository, name, participant_id)
  repository.with_aggregate(Workshops::Edition.new(name), "WorkshopEdition$#{name}") do |edition|
    edition.register(participant_id)
  end
end

def cancel_edition(repository, name)
  repository.with_aggregate(Workshops::Edition.new(name), "WorkshopEdition$#{name}") do |edition|
    edition.cancel
  end
end

# happy path
register_participant(repository, 'London', 123)
register_participant(repository, 'London', 234)
register_participant(repository, 'London', 345)

stream = event_store.read.stream('WorkshopEdition$London')
stored_events = stream.map(&:class)
assert_all stored_events, [
  Workshops::ParticipantRegisteredForEdition,
  Workshops::ParticipantRegisteredForEdition,
  Workshops::ParticipantRegisteredForEdition,
]
stored_data = stream.map(&:data)
assert_all stored_data, [
  {edition: 'London', participant_id: 123},
  {edition: 'London', participant_id: 234},
  {edition: 'London', participant_id: 345},
]
puts "Ok"

# failed invariants
register_participant(repository, 'Paris', 123)
cancel_edition(repository, 'Paris')
begin
  register_participant(repository, 'Paris', 234)
rescue Workshops::NoAvailableSeats
  puts "Ok, expected"
end

stream = event_store.read.stream('WorkshopEdition$Paris')
stored_events = stream.map(&:class)
assert_all stored_events, [
  Workshops::ParticipantRegisteredForEdition,
  Workshops::EditionCancelled,
]
stored_data = stream.map(&:data)
assert_all stored_data, [
  {edition: 'Paris', participant_id: 123},
  {edition: 'Paris'},
]
puts "Ok"

# concurrency error (simulated)
begin
  repository.with_aggregate(Workshops::Edition.new('Rome'), "WorkshopEdition$Rome") do |edition|
    event_store.publish(Workshops::ParticipantRegisteredForEdition.new(data:{edition: 'Rome', participant_id: 999}), stream_name: 'WorkshopEdition$Rome')
    edition.register(123)
  end
rescue RubyEventStore::WrongExpectedEventVersion
  puts "Ok, expected"
end

stream = event_store.read.stream('WorkshopEdition$Rome')
stored_events = stream.map(&:class)
assert_all stored_events, [
  Workshops::ParticipantRegisteredForEdition,
]
stored_data = stream.map(&:data)
assert_all stored_data, [
  {edition: 'Rome', participant_id: 999},
]
puts "Ok"

puts "DONE"