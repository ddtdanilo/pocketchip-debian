/*
 * gles2-bench: open an X11 window, draw shaded triangles with OpenGL ES 2
 * through EGL, and print the renderer and frames per second.
 *
 * Build: gcc -O2 -o gles2-bench gles2-bench.c -lEGL -lGLESv2 -lX11 -lm
 * Run:   DISPLAY=:0 ./gles2-bench [seconds] [triangles]
 */
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <X11/Xlib.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static const char *vs_src =
    "attribute vec2 pos;\n"
    "attribute vec3 col;\n"
    "uniform float angle;\n"
    "varying vec3 v_col;\n"
    "void main() {\n"
    "  float c = cos(angle), s = sin(angle);\n"
    "  gl_Position = vec4(c * pos.x - s * pos.y, s * pos.x + c * pos.y, 0.0, 1.0);\n"
    "  v_col = col;\n"
    "}\n";

static const char *fs_src =
    "precision mediump float;\n"
    "varying vec3 v_col;\n"
    "void main() { gl_FragColor = vec4(v_col, 1.0); }\n";

static double now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

static GLuint compile(GLenum type, const char *src)
{
    GLuint shader = glCreateShader(type);
    GLint ok = 0;
    char log[512];

    glShaderSource(shader, 1, &src, NULL);
    glCompileShader(shader);
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        glGetShaderInfoLog(shader, sizeof(log), NULL, log);
        fprintf(stderr, "shader error: %s\n", log);
        exit(1);
    }
    return shader;
}

int main(int argc, char **argv)
{
    double seconds = argc > 1 ? atof(argv[1]) : 10.0;
    int tris = argc > 2 ? atoi(argv[2]) : 500;
    const int width = 480, height = 272;
    Display *xdpy = XOpenDisplay(NULL);
    EGLDisplay dpy;
    EGLConfig cfg;
    EGLint n;
    EGLSurface surf;
    EGLContext ctx;
    Window win;
    GLuint prog;
    GLfloat *verts;
    GLint angle_loc;
    double start, last;
    long frames = 0;
    int i;

    static const EGLint cfg_attr[] = {
        EGL_RED_SIZE, 5, EGL_GREEN_SIZE, 6, EGL_BLUE_SIZE, 5,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE
    };
    static const EGLint ctx_attr[] = { EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE };

    if (!xdpy) {
        fprintf(stderr, "cannot open X display\n");
        return 1;
    }
    win = XCreateSimpleWindow(xdpy, DefaultRootWindow(xdpy), 0, 0, width, height,
                              0, 0, 0);
    XMapWindow(xdpy, win);
    XFlush(xdpy);

    dpy = eglGetDisplay((EGLNativeDisplayType)xdpy);
    if (!eglInitialize(dpy, NULL, NULL)) {
        fprintf(stderr, "eglInitialize failed: 0x%x\n", eglGetError());
        return 1;
    }
    if (!eglChooseConfig(dpy, cfg_attr, &cfg, 1, &n) || n < 1) {
        fprintf(stderr, "no EGL config\n");
        return 1;
    }
    surf = eglCreateWindowSurface(dpy, cfg, (EGLNativeWindowType)win, NULL);
    ctx = eglCreateContext(dpy, cfg, EGL_NO_CONTEXT, ctx_attr);
    if (surf == EGL_NO_SURFACE || ctx == EGL_NO_CONTEXT ||
        !eglMakeCurrent(dpy, surf, surf, ctx)) {
        fprintf(stderr, "EGL surface/context failed: 0x%x\n", eglGetError());
        return 1;
    }
    eglSwapInterval(dpy, 0);

    printf("EGL_VENDOR:  %s\n", eglQueryString(dpy, EGL_VENDOR));
    printf("EGL_VERSION: %s\n", eglQueryString(dpy, EGL_VERSION));
    printf("GL_VENDOR:   %s\n", glGetString(GL_VENDOR));
    printf("GL_RENDERER: %s\n", glGetString(GL_RENDERER));
    printf("GL_VERSION:  %s\n", glGetString(GL_VERSION));

    prog = glCreateProgram();
    glAttachShader(prog, compile(GL_VERTEX_SHADER, vs_src));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, fs_src));
    glBindAttribLocation(prog, 0, "pos");
    glBindAttribLocation(prog, 1, "col");
    glLinkProgram(prog);
    glUseProgram(prog);
    angle_loc = glGetUniformLocation(prog, "angle");

    /* Overlapping triangles in a ring: lots of fill, like a small game scene. */
    verts = malloc(sizeof(GLfloat) * 15 * tris);
    for (i = 0; i < tris; i++) {
        float a = 6.2831853f * i / tris, r = 0.6f;
        GLfloat *v = verts + 15 * i;
        v[0] = 0.0f; v[1] = 0.0f;
        v[2] = 1.0f; v[3] = 0.2f; v[4] = 0.2f;
        v[5] = r * cosf(a); v[6] = r * sinf(a);
        v[7] = 0.2f; v[8] = 1.0f; v[9] = 0.2f;
        v[10] = r * cosf(a + 0.8f); v[11] = r * sinf(a + 0.8f);
        v[12] = 0.2f; v[13] = 0.2f; v[14] = 1.0f;
    }
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), verts);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(GLfloat), verts + 2);
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glViewport(0, 0, width, height);

    start = last = now();
    while (now() - start < seconds) {
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glUniform1f(angle_loc, (float)(now() - start));
        glDrawArrays(GL_TRIANGLES, 0, 3 * tris);
        eglSwapBuffers(dpy, surf);
        frames++;
        if (now() - last >= 2.0) {
            printf("%.1f fps\n", frames / (now() - start));
            fflush(stdout);
            last = now();
        }
    }
    printf("average: %.1f fps over %ld frames (%d triangles per frame)\n",
           frames / (now() - start), frames, tris);
    return 0;
}
