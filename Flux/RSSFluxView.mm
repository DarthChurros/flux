
#import "RSSFluxView.h"

#import "RSSFluxConfigurationWindowController.h"

#import "RSSUserDefaults+Constants.h"

#import "RSSFluxSettings.h"

#include "Flux.h"

#import <OpenGL/gl.h>

@interface RSSFluxView ()
{
	BOOL _preview;
	BOOL _mainScreen;
	
	BOOL _OpenGLIncompatibilityDetected;
	
	NSOpenGLView *_openGLView;
	
	scene *_scene;
	
	// Preferences
	
	RSSFluxConfigurationWindowController *_configurationWindowController;
}

+ (void)_initializeScene:(scene *)inScene withSettings:(RSSFluxSettings *)inSettings;

@end

@implementation RSSFluxView

+ (void)_initializeScene:(scene *)inScene withSettings:(RSSFluxSettings *)inSettings
{
	if (inSettings.standardSet==RSSFluxSetRandom)
	{
		NSUInteger tRandomSet;
		
		tRandomSet=(NSUInteger) SSRandomFloatBetween(RSSFluxSetRegular,RSSFluxSetGalactic);
		
		[inSettings resetSettingsToStandardSet:(RSSFluxSet) tRandomSet];
	}
	
	inScene->fluxesCount=(int)inSettings.numberOFluxFields;
	inScene->particlesPerFluxCount=(int)inSettings.numberOfParticlesPerFluxField;
	inScene->particleSize=(int)inSettings.particleSize;
	inScene->particleTrailLength=(int)inSettings.particleTrailLength;
	inScene->geometryType=(int)inSettings.geometryType;
	inScene->sphereGeometryComplexity=(int)inSettings.geometrySphereComplexity;
	
	inScene->randomizationFrequency=(int)inSettings.randomizationFrequency;
	inScene->expansionrate=(int)inSettings.expansionRate;
	inScene->rotationRate=(int)inSettings.rotationRate;
	inScene->crossWindSpeed=(int)inSettings.crossWindSpeed;
	inScene->instability=(int)inSettings.instability;
	inScene->motionBlur=(int)inSettings.motionBlur;
}

- (instancetype)initWithFrame:(NSRect)frameRect isPreview:(BOOL)isPreview
{
	self=[super initWithFrame:frameRect isPreview:isPreview];
	
	if (self!=nil)
	{
		_preview=isPreview;
		
		if (_preview==YES)
			_mainScreen=YES;
		else
			_mainScreen= (NSMinX(frameRect)==0 && NSMinY(frameRect)==0);
		
		[self setAnimationTimeInterval:0.05];
	}
	
	return self;
}

#pragma mark -

- (void) setFrameSize:(NSSize)newSize
{
	[super setFrameSize:newSize];
	
	if (_openGLView!=nil)
		[_openGLView setFrameSize:newSize];
}

#pragma mark -

- (void) drawRect:(NSRect) inFrame
{
	[[NSColor blackColor] set];
	
	NSRectFill(inFrame);
	
	if (_OpenGLIncompatibilityDetected==YES)
	{
		BOOL tShowErrorMessage=_mainScreen;
		
		if (tShowErrorMessage==NO)
		{
			NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
			ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
			
			tShowErrorMessage=![tDefaults boolForKey:RSSUserDefaultsMainDisplayOnly];
		}
		
		if (tShowErrorMessage==YES)
		{
			NSRect tFrame=[self frame];
			
			NSMutableParagraphStyle * tMutableParagraphStyle=[[NSParagraphStyle defaultParagraphStyle] mutableCopy];
			[tMutableParagraphStyle setAlignment:NSCenterTextAlignment];
			
			NSDictionary * tAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont systemFontSize]],NSFontAttributeName,
										  [NSColor whiteColor],NSForegroundColorAttributeName,
										  tMutableParagraphStyle,NSParagraphStyleAttributeName,nil];
			
			
			NSString * tString=NSLocalizedStringFromTableInBundle(@"Minimum OpenGL requirements\rfor this Screen Effect\rnot available\ron your graphic card.",@"Localizable",[NSBundle bundleForClass:[self class]],@"No comment");
			
			NSRect tStringFrame;
			
			tStringFrame.origin=NSZeroPoint;
			tStringFrame.size=[tString sizeWithAttributes:tAttributes];
			
			tStringFrame=SSCenteredRectInRect(tStringFrame,tFrame);
			
			[tString drawInRect:tStringFrame withAttributes:tAttributes];
		}
	}
}

#pragma mark -

- (void)startAnimation
{
	_OpenGLIncompatibilityDetected=NO;
	
	[super startAnimation];
	
	NSString *tIdentifier = [[NSBundle bundleForClass:[self class]] bundleIdentifier];
	ScreenSaverDefaults *tDefaults = [ScreenSaverDefaults defaultsForModuleWithName:tIdentifier];
	
	BOOL tBool=[tDefaults boolForKey:RSSUserDefaultsMainDisplayOnly];
	
	if (tBool==YES && _mainScreen==NO)
		return;
	
	// Add OpenGLView
	
	NSOpenGLPixelFormatAttribute attribs[] =
	{
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFADepthSize,(NSOpenGLPixelFormatAttribute)16,
		NSOpenGLPFAMinimumPolicy,
		(NSOpenGLPixelFormatAttribute)0
	};
	
	NSOpenGLPixelFormat *tFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
	
	if (tFormat==nil)
	{
		_OpenGLIncompatibilityDetected=YES;
		return;
	}
	_openGLView = [[NSOpenGLView alloc] initWithFrame:[self bounds] pixelFormat:tFormat];
	
	if (_openGLView!=nil)
	{
		[_openGLView setWantsBestResolutionOpenGLSurface:YES];
		
		[self addSubview:_openGLView];
	}
	else
	{
		_OpenGLIncompatibilityDetected=YES;
		return;
	}
	
	[self lockFocus];
	
	[[_openGLView openGLContext] makeCurrentContext];
	
	glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	
	[[_openGLView openGLContext] flushBuffer];
	
	NSRect tPixelBounds=[_openGLView convertRectToBacking:[_openGLView bounds]];
	NSSize tSize=tPixelBounds.size;
	
	_scene=new scene();
	
	if (_scene!=NULL)
	{
		[RSSFluxView _initializeScene:_scene
							   withSettings:[[RSSFluxSettings alloc] initWithDictionaryRepresentation:[tDefaults dictionaryRepresentation]]];
		
		_scene->resize((int)tSize.width, (int)tSize.height);
		_scene->create();
	}
	
	const GLint tSwapInterval=1;
	CGLSetParameter(CGLGetCurrentContext(), kCGLCPSwapInterval,&tSwapInterval);
	
	[self unlockFocus];
}

- (void)stopAnimation
{
	[super stopAnimation];
	
	if (_scene!=NULL)
	{
		delete _scene;
		_scene=NULL;
	}
}

- (void)animateOneFrame
{
	if (_openGLView!=nil)
	{
		[[_openGLView openGLContext] makeCurrentContext];
		
		glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
		
		if (_scene!=NULL)
			_scene->draw();
		
		glFinish();
		
		[[_openGLView openGLContext] flushBuffer];
	}
}

#pragma mark - Configuration

- (BOOL)hasConfigureSheet
{
	return YES;
}

- (NSWindow*)configureSheet
{
	if (_configurationWindowController==nil)
		_configurationWindowController=[[RSSFluxConfigurationWindowController alloc] init];
	
	NSWindow * tWindow=_configurationWindowController.window;
	
	[_configurationWindowController restoreUI];
	
	return tWindow;
}

@end

