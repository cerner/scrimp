# Scrimp

This is a tool for testing Thrift services via a web browser (analogous to how you might test web services using a browser-based REST client).
Given the IDL files for the services, it provides a UI to help construct requests, invoke services, and display formatted responses.

Currently, services using the framed transport and either the compact or binary protocol are supported.

## Installation

    gem install scrimp

You must also have the Thrift compiler installed (tested with 0.9.0).

## Usage

To start the server, run the scrimp command and pass in the path to a folder containing your service's IDL files:

    scrimp folder/containing/thrift/files

Scrimp will recursively search the folder for files ending in `.thrift` and compile and load them. (By default, it invokes
the Thrift compiler as `thrift`; if you need to override this, use the `-t` option, e.g. `scrimp -t /usr/local/bin/thrift folder/containing/thrift/files`.)

Then open [http://localhost:7000](http://localhost:7000) (to override the port, use the `-p` option when starting scrimp).

A request editor is shown on the left. Initially you will see the 'structured editor'. This provides a list of the available services, functions,
and protocols, and generates a form for constructing requests for whatever function you select, based on the function's definition in your IDL.

Note that there will be a checkbox on the left of each optional field - this must be checked if you wish the field to be included in the request.

After you've constructed a request, click Invoke to send it; the result will be displayed on the right.

As an alternative to the structured editor, you can click 'edit request as json' to enter requests using the json format described below.
You can switch back and forth between the two editors without losing data; the json editor is helpful if you want to copy or paste a request or part of a request.

### JSON Representation

Scrimp uses the following json format to represent Thrift objects:

* Thrift booleans, numeric types, and strings are represented via the corresponding json primitives.
* Thrift lists and sets are represented by json arrays.
* Thrift structs are represented by json objects, with keys corresponding to the field names. Optional fields are omitted from the object when they are omitted from the struct.
* Thrift maps are represented as arrays of key-value pairs. (They aren't represented via json objects, since Thrift maps may contain complex keys.)
* Thrift enum values can be represented by either the string name of the enum constant, or the integer value assigned to the constant in the enum's definition.

Full example of a request you could paste into scrimp, invoking a service which takes a single argument (`people`) which is a set of structs containing
a string (`name`) and enum (`favoriteWord`):

    {
      "service": "ExampleService",
      "function": "greet",
      "protocol": "Thrift::CompactProtocol",
      "host": "localhost",
      "port": "9000",
      "args": {
        "people": [
          {
            "name": "Howard",
            "favoriteWord": "CYCLOPLEAN"
          },
          {
            "name": "David",
            "favoriteWord": "FANTOD"
          }
        ]
      }
    }

### Bypassing the GUI

You can POST requests in the above format directly to the scrimp server from the command line.  The command
for this, scrimpster, is included with the project.

```bash
./scrimpster request.json 'localhost:7000' 
```

The above example will issue a scrimp request to the scrimp server running on the localhost at port 7000 and will send
the data in request.json as the body of the request.  The response will be written to stdout.  If the scrimp server is
not specified it will default to the scrimp default of localhost:7000.

This tool can be easily scripted to run a battery of scrimp requests.  
For example to run scrimpster on a set of .json files in the current directory:
```bash
for json in *.json; do ./scrimpster $json > responses/$json; done
```



### Example Service

If you check out the project, there is a sample Thrift service to aid in testing. Start it with

    bundle exec sample/server.rb

It will start on port 9000. The Thrift compiler is assumed to be available as the command `thrift`; you can override this by passing
a `-t` argument, as described above for the `scrimp` command.

The IDL file is at sample/example.thrift, so start scrimp with:

    bundle exec bin/scrimp sample


## Contributing

This project is licensed under the Apache License, Version 2.0.

When contributing to the project please add your name to the CONTRIBUTORS.txt file. Adding your name to the CONTRIBUTORS.txt file signifies agreement to all rights and reservations provided by the License.

To contribute to the project execute a pull request through github. The pull request will be reviewed by the community and merged by the project committers. Please attempt to conform to the test, code conventions, and code formatting standards if any are specified by the project before submitting a pull request.

## LICENSE

Copyright 2013 Cerner Innovation, Inc.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0) Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
