module Workshops
  class Edition
    include AggregateRoot

    def initialize(name)
      @name = name
      @available_seats  = 20
    end

    def register(participant_id)
      raise NoAvailableSeats if @available_seats <= 0
      # here apply domain event...
    end

    # here implement cancelation of workshop edition

    private
    # here apply the state changes
  end
end