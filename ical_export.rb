require 'rubygems'

# If you're using bundler, you will need to add this
require 'bundler/setup'

require 'sinatra'
require 'active_record'
require 'date'
require 'ri_cal'

ActiveRecord::Base.default_timezone = :utc #Termine in der Datenbank sind UTC

configure do
  mime_type :ical, "text/calendar"
end
ActiveRecord::Base.establish_connection(
  :adapter => 'mysql2',
  :username => 'root',
  :database => 'thwkoeln',
  :host => '127.0.0.1'
)

class DateContent < ActiveRecord::Base
  set_table_name "content_type_date"
  set_primary_key "vid"
  belongs_to :node, :foreign_key => "vid", :primary_key => "vid"
end
class Node < ActiveRecord::Base
  set_table_name 'node_revisions'
  set_primary_key 'vid'
end

get '/:da.ical' do |da|
  content_type :ical
  date_content_list = DateContent.where(["field_date_value >= ?",DateTime.now - 12])
  unless da == "ov"
    date_content_list = date_content_list.where(["field_dienstart_value = ?",da])
  end
  
  cal = RiCal.Calendar do |cal|
    #Termine vor ueber einem Jahr interessieren nicht.
    date_content_list.includes(:node).each do |dc|
      cal.event do |event|
        event.dtstart = DateTime.parse("#{dc.field_date_value.getutc}")
        event.dtend = DateTime.parse("#{dc.field_date_value2.getutc}")
        event.description = description_str(dc)
        event.summary = dc.node.title if dc.node
        event.organizer = dc.field_contact_value if dc.field_contact_value.present?
        event.contact = dc.field_email_email if dc.field_email_email.present?
        event.url = dc.field_url_url unless dc.field_url_url.blank?
      end
    end
  end
  cal.to_s
end

private
def description_str(dc)
  n = dc.node || Node.new
  desc = n.body
  if dc.field_contact_value.present? || dc.field_email_email.present?
          desc += "\nKontakt: "
          desc += dc.field_contact_value if dc.field_contact_value.present?
          desc += " <" if dc.field_contact_value.present? and dc.field_email_email.present?
          desc += dc.field_email_email if dc.field_email_email.present?
          desc += "> " if dc.field_contact_value.present? and dc.field_email_email.present?
  end
  return desc
end