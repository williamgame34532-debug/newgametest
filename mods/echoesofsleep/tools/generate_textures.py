#!/usr/bin/env python3
"""Generates every texture of Echoes of Sleep. Entity textures are painted per box face, following the UV
layout read straight from the Java models (tex_entities.py); items, blocks, armor layers and HUD textures
come from tex_items.py."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import tex_entities  # noqa: E402
import tex_items  # noqa: E402

if __name__ == '__main__':
    tex_entities.run()
    tex_items.run()
    print('textures written')
