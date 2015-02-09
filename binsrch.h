/*
 *  binsrch.h
 *  WNShell3
 *
 *  Created by hogwood on Wed Apr 24 2002.
 *  Copyright (c) 2002 Tinc. All rights reserved.
 *
 */

#include <stdio.h>

char *bin_search(char *searchkey, FILE *fp);
void copyfile(FILE *fromfp, FILE *tofp);
char *replace_line(char *new_line, char *searchkey, FILE *fp);
char *insert_line(char *new_line, char *searchkey, FILE *fp);
