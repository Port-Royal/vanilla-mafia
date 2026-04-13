module NewsHelper
  NEWS_PHOTO_VARIANTS = {
    thumbnail: { resize_to_limit: [ 800, 600 ], saver: { quality: 85 } },
    full: { resize_to_limit: [ 1200, 900 ], saver: { quality: 90 } },
    zoom: { resize_to_limit: [ 2400, 1800 ], saver: { quality: 90 } },
    admin_form: { resize_to_limit: [ 400, 400 ], saver: { quality: 80 } }
  }.freeze

  def news_photo_variant(photo, variant)
    photo.variant(NEWS_PHOTO_VARIANTS.fetch(variant))
  end
end
