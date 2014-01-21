# Users recipe

Manage local users via databags

## See Also

ssh::private_keys recipe to deliver private keys securely.

## Databag format

The databag 'users' should contain entries like this:

joe.json

    {
      "id": "joe",
      "username": "joe",
      "uid": 1234,
      "groups": ["admin", "group1", "group2"],
      "shell": "\/bin\/bash",
      "comment": "Joey Fatone",
      "ssh_keys": "ssh-dss ....\nssh-dss ....\n",
      "nologin" : true
    }

Note that JSON requires that newlines in strings be escaped as '\n' - so if
you have newlines in the ssh_keys field, you must escape them.

The username attribute is optional, and defaults to the value of the 'id'
value.  It is there to bypass restrictions on the contents of the id attribute
(you cannot have an id with a dot, for example; so to create user joe.smith,
you would use id joe_smith and username joe.smith).

Set the "remove" attribute in the databag to delete the user.

Set the nologin flag to set the account to be NL under omnios (see man passwd).

## Attributes

In your nodes and roles, add entries like this:

    :users => { 
      :enabled => true, # True by default, set to false to disable cookbook
      :groups => [ 'admin', 'webdev' ] 
    }

This will cause a databag search for all users of the admin and webdev groups,
and make sure they are added.

## Weak Templating of Authorized Keys

This recipe will create the home directories, and also create the SSH
authorized key file, if it does not already exist. Once it exists (by chef or
other forces), it will not be changed.
