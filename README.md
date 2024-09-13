# Project Description

FlexIni allows you to load, utilize, and save one or more ini files within your Bash script.
Values from the ini files are stored in an associative array and remain there until you initiate a save operation.
This library was based on the ini/config management feature provided by [Bashly](https://github.com/DannyBen/bashly).
Big thanks to Bashly for making writing Bash scripts significantly more enjoyable!

# Installation

The easiest way to "install" this is just to copy the flex_ini.sh into your project and add the line `source /path/to/flex_ini.sh` to your script to make the functionality available.

# Usage

You'll need to load an ini file and (if using multiple ini files within a script) set the ini id.
The ini id is optional, so if you're only loading one ini file or if you started with one and now need to add a second, you can have some things which omit it, which populates the default_ini array, and some that specify it, which will populate the named array.
Values can be set and read with or without sections:

```
section = nope!
email = email@email.com

[docker]
installed = false

[docker-ce]
installed = true
```

### Load one or more ini files:

```
flex_ini_load "./app/global_settings.ini" "global"
flex_ini_load "./app/tenants/big-corp/settings.ini" "big-corp"
```

### Reload a previously-loaded ini file:

```
flex_ini_reload "your_ini_id"
```

### Clear an ini id from our loaded config:

```
flex_ini_clear "your_ini_id"
```

### Get a value:

```
flex_ini_get "your.key" "your_ini_id"
```

### Check if a key exists in an array:

```
flex_ini_has "your.key" "your_ini_id"
```

### Create/update a value (and save):

```
flex_ini_update "your.key" "the value" "your_ini_id"

# Optional saving of your ini at this stage
flex_ini_save "your_ini_id"
```

### Delete a value (and save):

```
flex_ini_delete "the.key" "your_ini_id"

# Optional saving of your ini at this stage
flex_ini_save "your_ini_id"
```

### Save your ini file:

```
flex_ini_save "your_ini_id"
```

### Save your ini values to a different file (save as):

```
flex_ini_save_as "/path/to/save/as/file.ini" "your_ini_id"
```

### Get the changed status of an array:

```
flex_ini_has_unsaved "your_ini_id"
```

### Reset all of the currently-loaded data (but don't delete the files):

```
flex_ini_reset
```

### Show all the values of a particular array:

```
flex_ini_show "your_ini_id"
```

### Get all the keys in an array:

```
flex_ini_keys "your_ini_id"
```

# Default Settings

If you want to override a default setting, you may change these or, probably better, change them when your script initializes after you source flex_ini.sh.

### Auto-save on changes

This setting affects whether any change operations will also trigger a save operation.
This can be helpful in cases where you know you're going to be updating only a setting or two, but should be avoided in the case where you are going to be doing tons and tons of updates.
This will be less critical when the bulk update feature is ready.

```
auto_save_on_changes=false
```

### Back up saved changes

This setting affects whether we make a your_settings.ini.bak file before we replace what's there.
It's not a foolproof backup system, obviously, but it can help in case something goes wrong while you're testing.

```
back_up_changes_on_save=true
```

### Back up saved changes during save-as

This setting shouldn't really, I don't think, be needed, but I still added it for transparency.
By default, the file you specify during a save-as operation isn't backed up if it already exists.

```
back_up_changes_on_save_as=false
```

### Temp Directory

This allows you to override the directory used to store the temp files we make before saving.

```
tmp_directory="/tmp"
```
