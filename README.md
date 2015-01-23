# yokozuna_error_patch
Yokozuna modifications to improve error handling and visibility.

## Patch Riak

Copy the generated beams into the basho-patches directory. The basho-patches directory for your platform can be found here: [http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches](http://docs.basho.com/riak/latest/ops/running/rolling-upgrades/#Basho-Patches)

```
cp ebin/*.beam /usr/lib64/riak/lib/basho-patches/
```

### For testing, compilation of this project can be done with make

```
make
```

## Initial Setup

The `yz_err` bucket-type and index will be automatically created the first time an error occurs. To set it up manually in preparation for future errors, perform the following steps:

Attach to a running patched riak instance

```
riak attach
```

Once in the erlang shell, run the following erlang snippet:

```
yz_errors:setup_error_bucket().
```

NOTE: Use "Ctrl-C a" to exit the shell. q() or init:stop() will terminate the riak node.


## Usage

The following are the fields indexed by the yz_err index

* `_yz_err_msg_s`: The string returned by yz_solr:index upon failure. Includes details from solr about the error
* `_yz_err_rb_s`: The bucket from the failed object
* `_yz_err_rk_s`: The key from the failed object
* `_yz_err_rt_s`: The bucket type from the failed object
* `_yz_rb`: The bucket which this new error object is stored. It is the original bucket type concatenated with the original bucket with a "." in between them
* `_yz_rk`: The original key from the failed object is reused for the indexed error object
* `_yz_rt`: The error bucket type is "yz_err"

Following is an example record returned from the query `curl 'http://localhost:8098/search/query/yz_err?wt=json&q=*:*'`: 

```
{
    "_yz_err_msg_s": "{\"Failed to index docs\",\n {ok,\"400\",\n     [{\"Content-Type\",\"application/json; charset=UTF-8\"},\n      {\"Transfer-Encoding\",\"chunked\"}],\n     <<\"{\\\"responseHeader\\\":{\\\"status\\\":400,\\\"QTime\\\":2},\\\"error\\\":{\\\"msg\\\":\\\"Invalid Date String:'blahblahblah'\\\",\\\"code\\\":400}}\\n\">>}}",
    "_yz_err_rb_s": "mybucket",
    "_yz_err_rk_s": "date4",
    "_yz_err_rt_s": "mytype",
    "_yz_id": "1*yz_err*mytype.mybucket*date4*63",
    "_yz_rb": "mytype.mybucket",
    "_yz_rk": "date4",
    "_yz_rt": "yz_err"
}
```