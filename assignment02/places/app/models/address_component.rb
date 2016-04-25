class AddressComponent
  attr_reader :long_name, :short_name, :types

  def initialize(params={})
    Rails.logger.debug("instantiating Address Component (#{params})")
    @long_name=params[:long_name]
    @short_name=params[:short_name]
    @types=params[:types]
  end
end
