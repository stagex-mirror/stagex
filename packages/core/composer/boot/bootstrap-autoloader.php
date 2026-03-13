<?php

// Official implementation class from the PSR-4 spec
// https://github.com/php-fig/fig-standards/blob/master/accepted/PSR-4-autoloader-examples.md
class Psr4AutoloaderClass
{
    /**
     * An associative array where the key is a namespace prefix and the value
     * is an array of base directories for classes in that namespace.
     *
     * @var array
     */
    protected array $prefixes = array();

    /**
     * Register loader with SPL autoloader stack.
     *
     * @return void
     */
    public function register(): void
    {
        spl_autoload_register(array($this, 'loadClass'));
    }

    /**
     * Adds a base directory for a namespace prefix.
     *
     * @param string $prefix The namespace prefix.
     * @param string $base_dir A base directory for class files in the
     * namespace.
     * @param bool $prepend If true, prepend the base directory to the stack
     * instead of appending it; this causes it to be searched first rather
     * than last.
     * @return void
     */
    public function addNamespace(string $prefix, string $base_dir, $prepend = false): void
    {
        // normalize namespace prefix
        $prefix = trim($prefix, '\\') . '\\';

        // normalize the base directory with a trailing separator
        $base_dir = rtrim($base_dir, DIRECTORY_SEPARATOR) . '/';

        // initialize the namespace prefix array
        if (isset($this->prefixes[$prefix]) === false) {
            $this->prefixes[$prefix] = array();
        }

        // retain the base directory for the namespace prefix
        if ($prepend) {
            array_unshift($this->prefixes[$prefix], $base_dir);
        } else {
            array_push($this->prefixes[$prefix], $base_dir);
        }
    }

    /**
     * Loads the class file for a given class name.
     *
     * @param string $class The fully-qualified class name.
     * @return string|false The mapped file name on success, or boolean false on
     * failure.
     */
    public function loadClass(string $class): string|false
    {
        // the current namespace prefix
        $prefix = $class;

        // work backwards through the namespace names of the fully-qualified
        // class name to find a mapped file name
        while (false !== $pos = strrpos($prefix, '\\')) {

            // retain the trailing namespace separator in the prefix
            $prefix = substr($class, 0, $pos + 1);

            // the rest is the relative class name
            $relative_class = substr($class, $pos + 1);

            // try to load a mapped file for the prefix and relative class
            $mapped_file = $this->loadMappedFile($prefix, $relative_class);
            if ($mapped_file) {
                return $mapped_file;
            }

            // remove the trailing namespace separator for the next iteration
            // of strrpos()
            $prefix = rtrim($prefix, '\\');
        }

        // never found a mapped file
        return false;
    }

    /**
     * Load the mapped file for a namespace prefix and relative class.
     *
     * @param string $prefix The namespace prefix.
     * @param string $relative_class The relative class name.
     * @return string|false Boolean false if no mapped file can be loaded, or the
     * name of the mapped file that was loaded.
     */
    protected function loadMappedFile(string $prefix, string $relative_class): string|false
    {
        // are there any base directories for this namespace prefix?
        if (isset($this->prefixes[$prefix]) === false) {
            return false;
        }

        // look through base directories for this namespace prefix
        foreach ($this->prefixes[$prefix] as $base_dir) {

            // replace the namespace prefix with the base directory,
            // replace namespace separators with directory separators
            // in the relative class name, append with .php
            $file = $base_dir
                . str_replace('\\', '/', $relative_class)
                . '.php';

            // if the mapped file exists, require it
            if ($this->requireFile($file)) {
                // yes, we're done
                return $file;
            }
        }

        // never found it
        return false;
    }

    /**
     * If a file exists, require it from the file system.
     *
     * @param string $file The file to require.
     * @return bool True if the file exists, false if not.
     */
    protected function requireFile(string $file): bool
    {
        if (file_exists($file)) {
            require $file;
            return true;
        }
        return false;
    }
}

// Load the composer.lock file
try {
    $lockContent = file_get_contents(dirname(__DIR__) . '/composer.lock');
    $lockData = json_decode($lockContent, true);

    if (!isset($lockData['packages'])) {
        throw new Exception("composer.lock does not contain 'packages' section.");
    }

    $packages = $lockData['packages'];
} catch (Exception $e) {
    die("Error parsing composer.lock: " . $e->getMessage());
}

// Arrays to store namespace to directory mappings
$filesToRequire = [];
$autoloader = new Psr4AutoloaderClass();

// Exclude polyfill packages for PHP < 8.4
$excludedPackages = [
    'symfony/polyfill-php73',
    'symfony/polyfill-php80',
    'symfony/polyfill-php81'
];

// Build the maps and handle static file and classmap inclusions
foreach ($packages as $package) {
    $packageName = $package['name'];
    $basePath = dirname(__DIR__) . '/vendor/' . $packageName . '/';

    if (in_array($packageName, $excludedPackages)) continue;
    if (!isset($package['autoload'])) continue;

    $autoload = $package['autoload'];

    // PSR-4
    if (isset($autoload['psr-4'])) {
        foreach ($autoload['psr-4'] as $namespace => $relativePath) {
            $autoloader->addNamespace($namespace, $basePath . $relativePath);
        }
    }

    // Classmap
    if (isset($autoload['classmap'])) {
        foreach ($autoload['classmap'] as $dir) {
            $absoluteDir = $basePath . $dir;
            if (is_dir($absoluteDir)) {
                $iterator = new RecursiveIteratorIterator(
                    new RecursiveDirectoryIterator($absoluteDir)
                );

                foreach ($iterator as $file) {
                    if ($file->getExtension() === 'php') {
                        $file = (string) $file;
                        if (!in_array($file, $filesToRequire)) {
                            $filesToRequire[] = $file;
                        }
                    }
                }
            } elseif (is_file($basePath . $dir)) {
                $file = $basePath . $dir;
                if (!in_array($file, $filesToRequire)) {
                    $filesToRequire[] = $file;
                }
            }
        }
    }

    // Files
    if (isset($autoload['files'])) {
        foreach ($autoload['files'] as $file) {
            $filePath = $basePath . $file;
            if (is_file($filePath)) {
                if (!in_array($filePath, $filesToRequire)) {
                    array_unshift($filesToRequire, $filePath);
                }
            }
        }
    }
}

// Add composer own source code
$autoloader->addNamespace('Composer', dirname(__DIR__) . '/src/Composer', true);

$autoloader->register();

// Require files from classMap or files autoload
foreach ($filesToRequire as $file) {
    require $file;
}
