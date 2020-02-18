module Workshops
  ParticipantRegisteredForEdition = Class.new(RailsEventStore::Event)
  EditionCancelled = Class.new(RailsEventStore::Event)

  NoAvailableSeats = Class.new(StandardError)
end
