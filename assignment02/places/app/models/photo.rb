class Photo
  attr_accessor :id, :location
  attr_writer :contents

  def initialize(params={})
    @id=params[:_id].to_s if !params[:_id].nil?
    @location=Point.new(params[:metadata][:location]) if !params[:metadata].nil?
    @place=params[:metadata][:place] if !params[:metadata].nil?
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def persisted?
    !@id.nil?
  end

  def save
    if !persisted?
      gps=EXIFR::JPEG.new(@contents).gps
      @contents.rewind
      @location=Point.new(lng: gps.longitude, lat: gps.latitude)
      description={}
      description[:content_type]="image/jpeg"
      description[:metadata]={}
      description[:metadata][:location]=@location.to_hash
      description[:metadata][:place]=@place
      grid_file=Mongo::Grid::File.new(@contents.read, description)
      @id=self.class.mongo_client.database.fs.insert_one(grid_file).to_s
    else
      description={}
      description[:metadata]={}
      description[:metadata][:location]=@location.to_hash if !@location.nil?
      description[:metadata][:place]=@place
      self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(@id))
        .update_one(:$set=>description)
    end
  end

  def self.all(offset=0, limit=nil)
    result=self.mongo_client.database.fs.find.skip(offset)
    result=result.limit(limit) if !limit.nil?
    result.map {|doc| Photo.new(doc)}
  end

  def self.find id
    file=self.mongo_client.database.fs.find(:_id=>BSON::ObjectId.from_string(id)).first
    return file.nil? ? nil : Photo.new(file)
  end

  def contents
    file=self.class.mongo_client.database.fs.find_one(:_id=>BSON::ObjectId.from_string(@id))
    if file
      buffer=""
      file.chunks.reduce([]) do |x, chunk|
        buffer << chunk.data.data
      end
      return buffer
    end
  end

  def destroy
    self.class.mongo_client.database.fs.delete(BSON::ObjectId.from_string(@id))
  end

  def find_nearest_place_id max_meters
    result=Place.near(@location, max_meters).projection(_id: true).first
    return result.nil? ? nil : result[:_id]
  end

  def place
    return @place.nil? ? nil : Place.find(@place.to_s)
  end

  def place=(place)
    @place=case place
      when String
        BSON::ObjectId.from_string(place)
      when Place
        BSON::ObjectId.from_string(place.id)
      when BSON::ObjectId
        place
      else
        nil
      end
  end

  def self.find_photos_for_place id
    id=id.is_a?(String) ? BSON::ObjectId.from_string(id) : id
    self.mongo_client.database.fs.find(:"metadata.place"=>id)
  end
end
