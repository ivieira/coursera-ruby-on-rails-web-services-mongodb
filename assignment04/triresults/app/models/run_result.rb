class RunResult < LegResult
  field :mmile, as: :minute_mile, type: Float

  def calc_ave
    if event and secs
      miles = event.miles
      self.minute_mile = miles.nil? ? nil : (secs/60)/miles
    end
  end
end
