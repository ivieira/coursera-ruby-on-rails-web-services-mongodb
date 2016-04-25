class Place
  include ActiveModel::Model
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params={})
    Rails.logger.debug("instantiating Place (#{params})")
    @id=params[:_id].to_s
    @address_components=params[:address_components].map {|a| AddressComponent.new(a)} if !params[:address_components].nil?
    @formatted_address=params[:formatted_address]
    @location=Point.new(params[:geometry][:geolocation])
  end

  def persisted?
    !@id.nil?
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    self.mongo_client['places']
  end

  def self.load_all file
    hash=JSON.parse(file.read)
    self.collection.insert_many(hash)
  end

  def self.find_by_short_name short_name
    self.collection.find({:"address_components.short_name" => short_name})
  end

  def self.to_places collection
    collection.map {|doc| Place.new(doc)}
  end

  def self.find id
    id=BSON::ObjectId.from_string(id)
    result=self.collection.find({_id: id}).first
    result=Place.new(result) if !result.nil?
  end

  def self.all(offset=0, limit=nil)
    result=self.collection.find()
      .skip(offset)
    result=result.limit(limit) if !limit.nil?
    result.map {|doc| Place.new(doc)}
  end

  def destroy
    Rails.logger.debug {"destroying #{self}"}
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id))
      .delete_one
  end

  def self.get_address_components(sort={}, offset=0, limit=nil)
    pipeline=[
      {:$unwind=>'$address_components'},
      {:$project=>{:_id=>true, :address_components=>true, :formatted_address=>true, :'geometry.geolocation'=>true}}
    ]
    pipeline << {:$sort=>sort} if !sort.empty?
    pipeline << {:$skip=>offset}
    pipeline << {:$limit=>limit} if !limit.nil?
    self.collection.find.aggregate(pipeline)
  end

  def self.get_country_names
    self.collection.find.aggregate([
        {:$unwind=>"$address_components"},
        {:$match=>{:"address_components.types"=>"country"}},
        {:$group=>{:_id=>"$address_components.long_name"}}
      ]).to_a.map {|h| h[:_id]}
  end

  def self.find_ids_by_country_code country_code
    self.collection.find.aggregate([
        {:$match=>{:"address_components.short_name"=>country_code, :"address_components.types"=>"country"}},
        {:$project=>{:_id=>true}}
      ]).map {|doc| doc[:_id].to_s}
  end

  def self.create_indexes
    self.collection.indexes.create_one({:"geometry.geolocation"=>Mongo::Index::GEO2DSPHERE})
  end

  def self.remove_indexes
    self.collection.indexes.drop_one("geometry.geolocation_2dsphere")
  end

  def self.near(point, max_meters=nil)
    search_spec={:$near=>{:$geometry=>point.to_hash}}
    if max_meters
      search_spec[:$near][:$maxDistance]=max_meters
    end
    self.collection.find(:"geometry.geolocation"=>search_spec)
  end

  def near(max_meters=nil)
    self.class.to_places(self.class.near(@location, max_meters))
  end

  def photos(offset=0, limit=nil)
    result=Photo.find_photos_for_place(@id).skip(offset)
    result=result.limit(limit) if !limit.nil?
    result=result.map {|photo| Photo.new(photo)}
  end
end
