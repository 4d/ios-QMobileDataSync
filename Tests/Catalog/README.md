#  <table name>.catalog.json 

File which contains definition of one 4D table in JSON format.

This files are the result of HTTP request /rest/$catalog/<table name>

## Used only for test!

This files are for test purpose.

The DataSync process use the first the CoreData model which contains all the information to recreate the remote rest table definition.
(using `.api` functions)

Getting from server definition using rest, is only to compare with local core data model and to check that this application is compatible with the 4D server
