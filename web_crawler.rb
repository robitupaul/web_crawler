require 'httparty'
require 'nokogiri'

EUR = HTTParty.get('http://www.infovalutar.ro/bnr/azi/eur').parsed_response.to_f
MONTHS = {
  'ian' => '01',
  'feb' => '02',
  'mar' => '03',
  'apr' => '04',
  'mai' => '05',
  'iun' => '06',
  'iul' => '07',
  'aug' => '08',
  'sep' => '09',
  'oct' => '10',
  'noi' => '11',
  'dec' => '12'
}
BASE_URL = "http://anuntul.ro"
IMOBILIARE_URL = "#{BASE_URL}/anunturi-imobiliare-vanzari"
SEARCH_URL = "/?page="

def parse_page(page)
  Nokogiri::HTML(HTTParty.get(page))
end

def get_images(parsed_page)
  scripts = parsed_page.css('script').to_s
  images = scripts.scan(/images\s*=\s*\[[\s\S]*?\]/).first
  images.scan(/\/\/stor.*?\.jpg/)
end

def get_type(parsed_page)
  parsed_page.css('div.label-list li').each do |el|
    if el.text == 'Decomandat'
      return 'Detached'
    elsif el.text == 'Semidecomandat'
      return 'Semi-detached'
    end
  end
  'Undeclared'
end

def get_price(anunt)
  price = anunt.css('div.price-list').text.gsub(/\D+/, '')
  price.to_i * EUR
end

def get_date(parsed_page)
  string_date_array = parsed_page.css('div.loc-data').text.split(',')
  ora = string_date_array[2].strip

  if string_date_array[1].strip == 'ieri'
    yesterday = DateTime.now - 1
    return DateTime.parse(yesterday.strftime("%Y-%m-%dT#{ora}:00%z"))
  elsif string_date_array[1].strip =='azi'
    return DateTime.parse(DateTime.now.strftime("%Y-%m-%dT#{ora}:00%z"))
  end

  date = string_date_array[1].strip.split(' ')
  month = MONTHS[date[1]]
  DateTime.parse(DateTime.now.strftime("%Y-#{month}-#{date[0]}T#{ora}:00%z"))
end

def web_crawler(x,y,z)
  #Get the total number of pages
  total_pages = parse_page(IMOBILIARE_URL).css('li.btn_page a.inactiv_page').text.split('/')[1].gsub(/\D+/, '').to_i

  end_date = DateTime.now - x
  results = []

  (1..total_pages).each do |i|
    parsed_page = parse_page(IMOBILIARE_URL + SEARCH_URL + i.to_s)
    parsed_page.css('div.anunt-row').each do |anunt|
      url = anunt.css('div.title-anunt a').first["href"]
      price = get_price(anunt)
      date = get_date(anunt)

      next if price < y or price > z
      next if date >= end_date
      puts "Parsing #{url}..."
      parsed_anunt = parse_page(url)
      results << {
        url: url,
        images: get_images(parsed_anunt),
        type: get_type(anunt),
        price: price,
        date: date
      }
    end

  end
  results.to_json
end

puts web_crawler(ARGV[0].to_i, ARGV[1].to_i, ARGV[2].to_i)
