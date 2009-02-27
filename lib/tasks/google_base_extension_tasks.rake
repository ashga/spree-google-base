require 'net/ftp'

namespace :db do
  desc "Bootstrap your database for Spree."
  task :bootstrap  => :environment do
    # load initial database fixtures (in db/sample/*.yml) into the current environment's database
    ActiveRecord::Base.establish_connection(RAILS_ENV.to_sym)
    Dir.glob(File.join(GoogleBaseExtension.root, "db", 'sample', '*.{yml,csv}')).each do |fixture_file|
      Fixtures.create_fixtures("#{GoogleBaseExtension.root}/db/sample", File.basename(fixture_file, '.*'))
    end
  end
end

namespace :spree do
  namespace :extensions do
    namespace :google_base do
      desc "Copies public assets of the Google Base to the instance public/ directory."
      task :update => :environment do
        is_svn_git_or_dir = proc {|path| path =~ /\.svn/ || path =~ /\.git/ || File.directory?(path) }
        Dir[GoogleBaseExtension.root + "/public/**/*"].reject(&is_svn_git_or_dir).each do |file|
          path = file.sub(GoogleBaseExtension.root, '')
          directory = File.dirname(path)
          puts "Copying #{path}..."
          mkdir_p RAILS_ROOT + directory
          cp file, RAILS_ROOT + path
        end
      end
      task :generate => :environment do
        results = '<?xml version="1.0"?>' + "\n" + '<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">' + "\n" + _filter_xml(_build_xml) + '</rss>'
        File.open("#{SPREE_ROOT}/public/google_base.xml", "w") do |io|
          io.puts(results)
        end
      end
      task :transfer => :environment do
        ftp = Net::FTP.new('uploads.google.com')
        ftp.login('', '')
        ftp.put("#{SPREE_ROOT}/public/google_base.xml", 'google_base_test.xml')
        ftp.quit() 
      end
    end
  end
end

def _get_product_type(product)
  product_type = ''
  priority = 1000
  product.taxons.each do |taxon|
    if taxon.taxon_map.priority
      priority = taxon.taxon_map.priority
      product_type = taxon.taxon_map.product_type
    end
  end
  product_type
end

def _filter_xml(output)
  output.gsub('price', 'g:price')
end
  
def _build_xml
  returning '' do |output|
    xml = Builder::XmlMarkup.new(:target => output, :indent => 2, :margin => 1)
    xml.channel {
      xml.title 'Spree Demo Site'
      xml.link 'http://demo.spreehq.org/'
      xml.description 'Spree Demo'
      Product.find(:all).each do |product|  
        xml.item {
          xml.title product.name
          xml.link 'http://demo.spreehq.org/products/' + product.permalink
          xml.description product.description
          xml.price product.master_price
          #xml.id product.sku.to_s
          #xml.condition 'New'
          #xml.product_type _get_product_type(product)
          #xml.image_link 'public_root' + product.images.first.attachment.url(:product)
          #others: xml.brand, xml.isbn, xml.mpn, xml.upc, xml.weight, xml.color, xml.height, xml.length,
          #xml.payment_accepted, xml.payment_notes, xml.price_type, xml.quantity, xml.shipping, xml.size, xml.tax
        }
      end
    }
  end
end