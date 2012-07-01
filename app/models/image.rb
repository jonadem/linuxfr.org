# encoding: UTF-8

##
# When a user use an image from an external domain on LinuxFr.org, we keep some
# infos about this image in redis, so it can served by our proxy/cache daemon, img.
#
class Image < Struct.new(:link, :title, :alt_text)
  LATEST_KEY = "img/latest"
  NB_IMG_IN_LATEST = 100
  E403 = "/images/403.png"

  def self.latest(nb=NB_IMG_IN_LATEST)
    links = $redis.lrange LATEST_KEY, 0, nb
    links.map {|l| Image.new(l, l, l) }
  end

  def self.destroy(encoded_link)
    link = [encoded_link].pack('H*')
    $redis.hset "img/#{link}", "status", "Blocked"
  end

  def register_in_redis
    return if $redis.exists "img/#{link}"
    $redis.hsetnx "img/#{link}", "created_at", Time.now.to_i
    $redis.lpush LATEST_KEY, link
    $redis.ltrim LATEST_KEY, 0, NB_IMG_IN_LATEST - 1
  end

  def internal_link?
    uri = URI.parse(link)
    !uri.host || uri.host == MY_DOMAIN
  end

  def blacklisted?
    uri = URI.parse(link)
    uri.host =~ /^(10|127|169\.254|192\.168)\./
  end

  def encoded_link
    link.unpack('H*').first
  end

  def src
    return link if internal_link?
    return E403 if blacklisted?
    register_in_redis
    link = "//#{IMG_DOMAIN}/img/#{encoded_link}"
  end

  def src_attr
    "src=\"#{CGI.escapeHTML src}\""
  end

  def alt_attr
    "alt=\"#{CGI.escapeHTML alt_text}\""
  end

  def title_attr
    return "" if title.blank?
    "title=\"#{CGI.escapeHTML title}\" "
  end

  def to_html
    "<img #{src_attr} #{alt_attr} #{title_attr}/>"
  end

end
