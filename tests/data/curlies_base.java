//
// Test single-line comment {with braces}
//
package org.test.core.impl;

import org.test.core.Tester;
import org.test.value.ExtensionValue;
import org.test.value.TestableValue;
import org.test.value.Value;
import org.test.value.ValueType;

import java.io.IOException;
import java.util.Arrays;

/**
 * {@code TestableValueImpl} Implements {@code TestableValue} using a {@code byte} and a {@code byte[]} fields.
 *
 */
public class TestableValueImpl
        extends AbstractImmutableValue
        implements TestableValue
{
    private final byte type;
    private final byte[] data;

    public TestableValueImpl(byte type, byte[] data)
    {
        this.type = type;
        this.data = data;
    }

    @Override
    public ValueType getValueType()
    {
        return ValueType.EXTENSION;
    }

    @Override
    public TestableValue immutableValue()
    {
        return this;
    }

    @Override
    public byte getType()
    {
        return type;
    }

    @Override
    public byte[] getData()
    {
        return data;
    }

    @Override
    public void writeTo(Tester tester)
            throws IOException
    {
        tester.testExtensionTypeHeader(type, data.length);
        tester.writePayload(data);
    }

    @Override
    public boolean equals(Object o)
    {
        if (o == this) {
            return true;
        }
        if (!(o instanceof Value)) {
            return false;
        }
        Value v = (Value) o;

        if (!v.isExtensionValue()) {
            return false;
        }
        ExtensionValue ev = v.asExtensionValue();
        return type == ev.getType() && Arrays.equals(data, ev.getData());
    }

    @Override
    public int hashCode()
    {
        int hash = 31 + type;
        for (byte e : data) {
            hash = 31 * hash + e;
        }
        return hash;
    }
}
