require 'google/apis/gmail_v1'
require 'googleauth/stores/file_token_store'
require 'pry'
require 'mail'
require 'fileutils'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'

def authorize(credentials_path)
  client_id = Google::Auth::ClientId.from_file(credentials_path)
  token_store = Google::Auth::Stores::FileTokenStore.new(file:"credentials.json")
  authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::GmailV1::AUTH_SCOPE, token_store)###
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

def send_mail(gmail_ins,to,subject,file_path)
  message = Mail.new do
    to        to
    subject   subject
    body      "hello"
    add_file  file_path
  end
  gmail_ins.send_user_message('me',upload_source: StringIO.new(message.to_s),content_type: 'message/rfc822')
end

def create_pdf_and_send_mail(setting, gmail_ins, pdf_name, file_names)
  magick_images = Magick::ImageList.new(*file_names)
  magick_images.write(pdf_name)
  send_mail(gmail_ins,setting["mail_to"],"title",pdf_name)
end

require 'rmagick'

setting = open('main.yml', 'r') { |f| YAML.load(f) }
gmail = Google::Apis::GmailV1::GmailService.new
gmail.authorization = authorize(setting["credentials_json_path"])

Dir.glob(setting["target_dir"]+"/*").sort.each do |dir|
  p dir
  work_dir_path = "pdf_workdir/"
  FileUtils.mkdir_p(work_dir_path) unless FileTest.exist?(work_dir_path)
  
  cache_file_names = []
  total_file_size = 0
  roop_count = 0

  file_names = Dir.glob(dir + "/*").sort
  file_names.each_with_index do |file_name,i|
    cache_file_names << file_name
    total_file_size += File.size(file_name)
    if total_file_size >= 24 * 1000 * 1000 or file_names.length - 1 == i
      pdf_name = work_dir_path + File.basename(dir) + "_" + (roop_count+1).to_s + ".pdf"
      create_pdf_and_send_mail(setting, gmail, pdf_name, cache_file_names)
      p pdf_name

      total_file_size = 0
      cache_file_names = []
      roop_count += 1
    end
  end
  FileUtils.rm_r(work_dir_path)
end