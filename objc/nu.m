// nu.m
//  Top-level Nu functions.
//
//  Copyright (c) 2007 Tim Burks, Neon Design Technology, Inc.

#import "parser.h"
#import "symbol.h"
#import "Nu.h"
#import "extensions.h"
#import "object.h"
#import <unistd.h>

id Nu__zero = 0;
id Nu__null = 0;

@implementation Nu
+ (id<NuParsing>) parser
{
    return [[[NuParser alloc] init] autorelease];
}

@end

@interface NuApplication : NSObject
{
    NSMutableArray *arguments;
}

@end

static NuApplication *_sharedApplication = 0;

@implementation NuApplication
+ (NuApplication *) sharedApplication
{
    if (!_sharedApplication)
        _sharedApplication = [[NuApplication alloc] init];
    return _sharedApplication;
}

- (void) setArgc:(int) argc argv:(const char *[])argv
{
    arguments = [[NSMutableArray alloc] init];
    int i;
	// skip the first two.  They are usually "nush" and the script name.
    for (i = 2; i < argc; i++) {
        [arguments addObject:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
    }
}

- (NSArray *) arguments
{
    return arguments;
}

@end

void write_arguments(int argc, char *argv[])
{
    NSLog(@"launched with arguments");
    int i;
    for (i = 0; i < argc; i++) {
        NSLog(@"argv[%d]: %s", i, argv[i]);
    }
}

int NuMain(int argc, const char *argv[])
{
    Nu__zero = [NuZero zero];
    Nu__null = [NSNull null];

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // collect the command-line arguments
    [[NuApplication sharedApplication] setArgc:argc argv:argv];

	// perform a dirty hack
	[NSView exchangeInstanceMethod:@selector(retain)  withMethod:@selector(nuRetain)];
	[NSView exchangeInstanceMethod:@selector(release) withMethod:@selector(nuRelease)];

    // first we try to load main.nu from the application bundle.
    NSString *main_path = [[NSBundle mainBundle] pathForResource:@"main" ofType:@"nu"];
    if (main_path) {
        NSString *main_nu = [NSString stringWithContentsOfFile:main_path];
        if (main_nu) {
            NuParser *parser = [[NuParser alloc] init];
            id script = [parser parse: main_nu];
            [parser eval:script];
            [parser release];
            [pool release];
            return 0;
        }
    }
    // if that doesn't work, use the arguments to decide what to execute
    else if (argc > 1) {
        NuParser *parser = [[NuParser alloc] init];
        id script, result;
        bool didSomething = false;
        int i = 1;
        bool fileEvaluated = false;               // only evaluate one filename
        while (i < argc) {
            if (!strcmp(argv[i], "-e")) {
                i++;
                script = [parser parse:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
                result = [parser eval:script];
                didSomething = true;
            }
            else if (!strcmp(argv[i], "-f")) {
                i++;
                script = [parser parse:[NSString stringWithFormat:@"(load \"%s\")", argv[i]]];
                result = [parser eval:script];
            }
            else if (!strcmp(argv[i], "-i")) {
                [parser interact];
                didSomething = true;
            }
            else {
                if (!fileEvaluated) {
                    id string = [NSString stringWithContentsOfFile:[NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding]];
                    if (string) {
                        id script = [parser parse:string];
                        [parser eval:script];
                        fileEvaluated = true;
                    }
                    else {
                        // complain somehow. Throw an exception?
                        NSLog(@"Error: can't open file named %s", argv[i]);
                    }
                    didSomething = true;
                }
            }
            i++;
        }
        if (!didSomething)
            [parser interact];
        [parser release];
        [pool release];
        return 0;
    }
    // if there's no file, run at the terminal
    else {
        if (!isatty(stdin->_file)) {
            NuParser *parser = [[NuParser alloc] init];
            id string = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
            id script = [parser parse:string];
            [parser eval:script];
            [parser release];
            [pool release];
        }
        else {
            [pool release];
            return [NuParser main];
        }
    }
    return 0;
}

static int load_nu_files(NSString *bundleIdentifier, NSString *mainFile)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSBundle *bundle = [NSBundle bundleWithIdentifier:bundleIdentifier];
    NSString *main_path = [bundle pathForResource:mainFile ofType:@"nu"];
    if (main_path) {
        NSString *main_nu = [NSString stringWithContentsOfFile:main_path];
        if (main_nu) {
            id parser = [Nu parser];
            id script = [parser parse: main_nu];
            [parser eval:script];
        }
    }
    [pool release];
    return 0;
}

void NuInit()
{
    Nu__null = [NSNull null];
    Nu__zero = [NuZero zero];
    static int initialized = 0;
    if (!initialized) {
        initialized = 1;
        load_nu_files(@"nu.programming.framework", @"nu");
        load_nu_files(@"nu.programming.framework", @"cocoa");
        load_nu_files(@"nu.programming.framework", @"help");
    }
}