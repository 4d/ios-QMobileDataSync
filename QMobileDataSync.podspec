Pod::Spec.new do |s|

  # ―――  Spec Metadata  ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.name         = "QMobileDataSync"
  s.version      = "0.0.1"
  s.summary      = "A short description of QMobileDataSync."

  s.description  = <<-DESC
                   Synchronize data from rest API into DataStore
                   DESC

  s.homepage     = "https://project.wakanda.org/issues/89726"

  # ―――  Spec License  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.license      = "Copyright © 4D"

  # ――― Author Metadata  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.author             = { "Eric Marchand" => "eric.marchand@4d.com" }

  s.ios.deployment_target = "10.0"

  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  s.source       = { :git => "https://gitfusion.wakanda.io/qmobile/QMobileDataSync.git", :tag => "#{s.version}" }

  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.source_files  = "Sources/**/*.swift"

  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #

  s.dependency "XCGLogger"
  s.dependency "Prephirences"
  s.dependency "BrightFutures"
  s.dependency "QMobileAPI"
  s.dependency "QMobileDataStore"

end
