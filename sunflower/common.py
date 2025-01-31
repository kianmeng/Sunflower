import os
import gettext
import subprocess
import locale
import sys

from gi.repository import Gio, Pango

# user directories
class UserDirectory:
	DESKTOP = 'XDG_DESKTOP_DIR'
	DOWNLOADS = 'XDG_DOWNLOAD_DIR'
	TEMPLATES = 'XDG_TEMPLATES_DIR'
	PUBLIC = 'XDG_PUBLICSHARE_DIR'
	DOCUMENTS = 'XDG_DOCUMENTS_DIR'
	MUSIC = 'XDG_MUSIC_DIR'
	PICTURES = 'XDG_PICTURES_DIR'
	VIDEOS = 'XDG_VIDEOS_DIR'


# file mode formats
class AccessModeFormat:
	OCTAL = 0
	TEXTUAL = 1


# file size formats
class SizeFormat:
	LOCAL = 0
	SI = 1
	IEC = 2

	multiplier = {
			SI: 1000.0,
			IEC: 1024.0
		}
	unit_names = {
			SI: ['B','kB','MB','GB','TB'],
			IEC: ['B','KiB','MiB','GiB','TiB']
		}


MONOSPACE_FONT_STRING = None


def format_size(size, format_type, include_unit=True):
	"""Convert size to more human readable format"""
	result = size

	# format as localized decimal number
	if format_type == SizeFormat.LOCAL:
		result = ('{0}', '{0} B')[include_unit].format(locale.format('%d', size, True))

	# format based on specified standard
	else:
		names = SizeFormat.unit_names[format_type]
		multiplier = SizeFormat.multiplier[format_type]

		for name in names:
			if size < multiplier:
				# hide decimal places for byte sized values
				template = '{0:3.1f} {1}' if name != 'B' else '{0:3.0f} {1}'
				result = template.format(size, name)
				break

			size /= multiplier

	return result

def format_mode(mode, format):
	"""Convert mode to more human readable format"""
	result = ''

	if format == AccessModeFormat.TEXTUAL:
		# create textual representation
		mask = 256

		for i in 'rwxrwxrwx':
			result += i if mode & mask else '-'
			mask >>= 1

	elif format == AccessModeFormat.OCTAL:
		# create octal
		result = oct(mode)

	return result

def get_base_directory():
	"""Return base directory where application is installed."""
	return os.path.dirname(__file__)

def get_static_assets_directory():
	"""Return path to directory that holds static files"""
	script_dir = os.path.join(os.path.dirname(__file__), '..')
	prefix_dir = os.path.join(sys.prefix, 'share', 'sunflower')
	result = prefix_dir

	if os.path.exists(os.path.join(script_dir, 'images', 'sunflower.svg')):
		result = script_dir

	return result

def get_cache_directory():
	"""Get full path to cache files for curring user."""
	if 'XDG_CACHE_HOME' in os.environ:
		result = os.path.abspath(os.environ['XDG_CACHE_HOME'])
	else:
		result = os.path.expanduser('~/.cache')

	return result

def get_config_directory():
	"""Get full path to configuration files for current user."""
	result = os.path.expanduser('~/.config')

	if 'XDG_CONFIG_HOME' in os.environ:
		result = os.path.abspath(os.environ['XDG_CONFIG_HOME'])

	return result

def get_config_path():
	"""Get path to configuration files"""
	config_directory = get_config_directory()
	result = os.path.expanduser('~/.sunflower')

	if os.path.isdir(config_directory):
		return os.path.join(config_directory, 'sunflower')

def get_data_directory():
	"""Get full path to user data files."""
	result = os.path.expanduser('~/.local', 'share')

	if 'XDG_DATA_HOME' in os.environ:
		result = os.path.abspath(os.environ['XDG_DATA_HOME'])

	return result

def get_user_directory(directory):
	"""Get full path to current users predefined directory"""
	result = None
	config_file = os.path.join(get_config_directory(), 'user-dirs.dirs')

	if os.path.isfile(config_file):
		# read configuration file
		with open(config_file, 'r') as raw_file:
			lines = raw_file.read().splitlines(False)

		# get desired path
		for line in lines:
			data = line.split('=')

			if data[0] == directory:
				result = data[1].replace('$HOME', os.path.expanduser('~'))
				result = result.strip('"')
				break

	return result

def is_gui_app(command):
	"""Checks if command uses graphical user interfaces."""
	try:
		env = os.environ.copy()
		env.update({'LD_TRACE_LOADED_OBJECTS': '1'})
		output = subprocess.Popen(
							[command],
							env=env,
							stdout=subprocess.PIPE
						).communicate()

	except OSError as error:
		# report error to user
		raise error

	libraries = (b'libX11.so', b'libvlc.so', b'libwayland-client.so')
	matching = [library for library in libraries if library in output[0]]

	return len(matching) > 0

def executable_exists(command):
	"""Check if specified command exists in search path"""
	default_paths = os.pathsep.join(('/bin', '/usr/bin', '/usr/local/bin'))
	search_paths = os.environ.get('PATH', default_paths).split(os.pathsep)
	found_commands = [path for path in search_paths if os.path.exists(os.path.join(path, command))]

	return len(found_commands) > 0

def load_translation():
	"""Load translation and install global functions"""
	# get directory for translations
	base_path = os.path.dirname(get_static_assets_directory())
	directory = os.path.join(base_path, 'translations')

	# function params
	params = {
			'domain': 'sunflower',
			'fallback': True
		}

	# install translations from local directory if needed
	if os.path.isdir(directory):
		params.update({'localedir': directory})

	# get translation
	translation = gettext.translation(**params)

	# install global functions for translating
	__builtins__.update({
			'_': translation.gettext,
			'ngettext': translation.ngettext
		})

def decode_file_name(file_name):
	"""Replace surrogate codepoints in a filename with a replacement character
	to display non-UTF-8 filenames."""
	if isinstance(file_name, bytes):
		return file_name.decode('utf-8', 'replace')

	return decode_file_name(encode_file_name(file_name))

def encode_file_name(file_name):
	"""Encode filename to bytes so it can be passed to GI APIs that expect a file name
	(and specify `filename` as their argument type in the GIR bindings)."""
	return str(file_name).encode('utf-8', 'surrogateescape')

def get_monospace_font_string():
	"""Return monospace font name."""
	global MONOSPACE_FONT_STRING

	if MONOSPACE_FONT_STRING is None:
		schema = Gio.SettingsSchemaSource.get_default()
		gnome_interface = schema.lookup('org.gnome.desktop.interface',True)

		if gnome_interface is None:
			# not in gnome desktop environment, use 'monospace'
			MONOSPACE_FONT_STRING = 'monospace'
		else:
			settings = Gio.Settings.new('org.gnome.desktop.interface')
			MONOSPACE_FONT_STRING = settings.get_string('monospace-font-name')

	return MONOSPACE_FONT_STRING
