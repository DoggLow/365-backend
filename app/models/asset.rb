class Asset < ActiveRecord::Base
  belongs_to :attachable, polymorphic: true

  mount_uploader :file, FileUploader

  def image?
    file.content_type.start_with?('image') if file?
  end
end

class Asset::IdDocumentFile < Asset
end

class Asset::IdBillFrontFile < Asset
end

class Asset::IdBillBackFile < Asset
end

class Asset::IdSelfieFile < Asset
end
