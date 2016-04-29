class Point
  attr_accessor :longitude, :latitude

  def initialize(lng=nil, lat=nil)
    @longitude = lng
    @latitude = lat
  end

  def mongoize
    {:type=>"Point", :coordinates=>[@longitude, @latitude]}
  end

  def self.demongoize(object)
    case object
    when Point then object
    when Hash then
      Point.new(object[:coordinates][0], object[:coordinates][1])
    else object
    end
  end

  def self.mongoize(object)
    case object
    when Point then object.mongoize
    when Hash then
      Point.new(object[:coordinates][0], object[:coordinates][1]).mongoize
    else object
    end
  end

  def self.evolve(object)
    case object
    when Point then object.mongoize
    else object
    end
  end
end
